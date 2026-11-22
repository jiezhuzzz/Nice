use std::collections::BTreeMap;

use nicebar_core::bar::{self, Bar, Rendered, Tab};
use nicebar_core::sample::{Meter, Sample};
use nicebar_core::theme::{Theme, ThemeError};
use zellij_tile::prelude::*;

const POLL_SECONDS: f64 = 2.0;
const PRIMING_SECONDS: f64 = 0.5;

/// Zellij (≥ 0.46) runs one shared instance for every pane of this plugin in a
/// session, so each event is decoded once rather than once per tab. Each pane
/// is a slot with its own configuration, and anything that differs between
/// attached clients lives in their `View`.
#[derive(Default)]
struct Nicebar {
    permission: Option<PermissionStatus>,
    session: Option<String>,
    bars: BTreeMap<SlotId, BarSlot>,
    views: BTreeMap<ClientId, View>,
    meter: Meter,
    polling: bool,
}

struct BarSlot {
    theme: Result<Theme, ThemeError>,
    stats_command: Option<String>,
}

#[derive(Default)]
struct View {
    mode: InputMode,
    tabs: Vec<Tab>,
    rendered: Rendered,
}

register_shared_plugin!(Nicebar);

impl ZellijSharedPlugin for Nicebar {
    fn load(&mut self, _configuration: BTreeMap<String, String>) {
        request_permission(&[
            PermissionType::ReadApplicationState,
            PermissionType::ChangeApplicationState,
            PermissionType::RunCommands,
        ]);
        subscribe(&[
            EventType::PermissionRequestResult,
            EventType::ModeUpdate,
            EventType::TabUpdate,
            EventType::Mouse,
            EventType::Timer,
            EventType::RunCommandResult,
            // Zellij drops the startup ModeUpdate when it beats the permission
            // grant and then skips identical resends, so the session name is
            // taken once from the costlier SessionUpdate instead.
            EventType::SessionUpdate,
        ]);
    }

    fn slot_added(&mut self, slot: Slot) {
        if slot.kind != SlotKind::Pane {
            return;
        }
        set_selectable(false);
        self.bars.insert(
            slot.id,
            BarSlot {
                theme: Theme::from_config(&slot.configuration),
                stats_command: slot.configuration.get("stats").cloned(),
            },
        );
        self.resume_polling();
    }

    fn slot_removed(&mut self, slot_id: SlotId) {
        self.bars.remove(&slot_id);
    }

    fn client_connected(&mut self, client_id: ClientId) {
        self.views.entry(client_id).or_default();
        self.resume_polling();
    }

    fn client_disconnected(&mut self, client_id: ClientId) {
        self.views.remove(&client_id);
    }

    fn update(&mut self, event: Event, context: EventContext) -> RenderResponse {
        match event {
            Event::PermissionRequestResult(status) => {
                self.permission = Some(status);
                self.resume_polling();
                RenderResponse::All
            }
            Event::ModeUpdate(info) => {
                if info.session_name.is_some() {
                    self.session = info.session_name;
                }
                self.update_views(context.client_id, |view| view.mode = info.mode)
            }
            Event::SessionUpdate(sessions, _) => {
                unsubscribe(&[EventType::SessionUpdate]);
                if let Some(current) = sessions
                    .into_iter()
                    .find(|session| session.is_current_session)
                {
                    self.session = Some(current.name);
                }
                RenderResponse::All
            }
            Event::TabUpdate(tabs) if tabs.iter().any(|tab| tab.active) => {
                self.update_views(context.client_id, |view| {
                    view.tabs = tabs.iter().map(bar_tab).collect();
                })
            }
            Event::Mouse(Mouse::LeftClick(_, column)) => {
                let position = context
                    .client_id
                    .and_then(|client_id| self.views.get(&client_id))
                    .and_then(|view| view.rendered.tab_at(column));
                if let Some(position) = position {
                    switch_tab_to(position as u32 + 1);
                }
                RenderResponse::Nothing
            }
            Event::RunCommandResult(exit_code, stdout, stderr, _) => {
                self.record_sample(exit_code, &stdout, &stderr);
                RenderResponse::All
            }
            Event::Timer(_) => {
                self.polling = false;
                self.resume_polling();
                RenderResponse::Nothing
            }
            _ => RenderResponse::Nothing,
        }
    }

    fn render(&mut self, _rows: usize, cols: usize, slot_id: SlotId, client_id: ClientId) {
        let Some(slot) = self.bars.get(&slot_id) else {
            return;
        };
        let theme = match (self.permission, &slot.theme) {
            (Some(PermissionStatus::Denied), _) => return notice("permissions denied", cols),
            (_, Err(error)) => return notice(&error.to_string(), cols),
            (_, Ok(theme)) => theme,
        };
        let view = self.views.entry(client_id).or_default();
        view.rendered = bar::render(
            &Bar {
                mode: mode_label(view.mode),
                session: self.session.as_deref(),
                tabs: &view.tabs,
                usage: self.meter.usage(),
            },
            theme,
            cols,
        );
        print!("{}", view.rendered.line);
    }
}

impl Nicebar {
    fn update_views(
        &mut self,
        client_id: Option<ClientId>,
        apply: impl Fn(&mut View),
    ) -> RenderResponse {
        let response = match client_id {
            Some(client_id) => {
                apply(self.views.entry(client_id).or_default());
                RenderResponse::Client(client_id)
            }
            None => {
                self.views.values_mut().for_each(apply);
                RenderResponse::All
            }
        };
        self.resume_polling();
        response
    }

    /// Each sample is scheduled only after the previous one reports, so a slow
    /// helper can never pile up processes.
    fn resume_polling(&mut self) {
        if self.polling || self.permission != Some(PermissionStatus::Granted) {
            return;
        }
        let command = self
            .bars
            .values()
            .find_map(|bar| bar.stats_command.as_deref());
        match command {
            Some(command) if !self.views.is_empty() => {
                run_command(&[command], BTreeMap::new());
                self.polling = true;
            }
            _ => self.meter.clear(),
        }
    }

    fn record_sample(&mut self, exit_code: Option<i32>, stdout: &[u8], stderr: &[u8]) {
        let sample = (exit_code == Some(0))
            .then(|| String::from_utf8_lossy(stdout).trim().parse::<Sample>());
        match sample {
            Some(Ok(sample)) => self.meter.record(sample),
            Some(Err(error)) => {
                eprintln!("nicebar: {error}");
                self.meter.clear();
            }
            None => {
                eprintln!(
                    "nicebar: stats helper exited with {exit_code:?}: {}",
                    String::from_utf8_lossy(stderr).trim()
                );
                self.meter.clear();
            }
        }
        set_timeout(if self.meter.is_priming() {
            PRIMING_SECONDS
        } else {
            POLL_SECONDS
        });
    }
}

fn notice(problem: &str, cols: usize) {
    print!("{}", bar::clip(&format!(" nicebar: {problem}"), cols));
}

fn mode_label(mode: InputMode) -> &'static str {
    match mode {
        InputMode::Normal => "NORMAL",
        InputMode::Locked => "LOCKED",
        InputMode::Pane => "PANE",
        InputMode::Tab => "TAB",
        InputMode::Resize => "RESIZE",
        InputMode::Move => "MOVE",
        InputMode::Scroll => "SCROLL",
        InputMode::EnterSearch | InputMode::Search => "SEARCH",
        InputMode::RenameTab | InputMode::RenamePane | InputMode::RenameSession => "RENAME",
        InputMode::Session => "SESSION",
        InputMode::Prompt => "PROMPT",
        InputMode::Tmux => "TMUX",
    }
}

fn bar_tab(info: &TabInfo) -> Tab {
    Tab {
        position: info.position,
        name: info.name.clone(),
        active: info.active,
        fullscreen: info.is_fullscreen_active,
        sync: info.is_sync_panes_active,
        floating: info.are_floating_panes_visible,
    }
}
