use std::collections::BTreeMap;

use crate::mode::ModeView;
use crate::remote::Remotes;
use nicebar_core::bar::{self, Bar, Rendered, Tab, Target};
use nicebar_core::sample::{Meter, Sample};
use nicebar_core::theme::{Appearance, ThemeError, Themes};
use zellij_tile::prelude::*;

mod mode;
mod remote;

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
    /// Zellij follows one host terminal's appearance for the whole session,
    /// not one per attached client.
    appearance: Option<Appearance>,
    /// Zellij also replays the latest appearance to a new subscriber, addressed
    /// to a client, and that replay can arrive after a newer session-wide
    /// report. It counts only until the session reports one.
    replayed_appearance: Appearance,
    bars: BTreeMap<SlotId, BarSlot>,
    views: BTreeMap<ClientId, View>,
    meter: Meter,
    remotes: Remotes,
    polling: bool,
}

struct BarSlot {
    themes: Result<Themes, ThemeError>,
    stats_command: Option<String>,
}

#[derive(Default)]
struct View {
    mode: ModeView,
    hosts: Vec<String>,
    dimmed: bool,
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
            EventType::PaneUpdate,
            EventType::Mouse,
            EventType::Timer,
            EventType::RunCommandResult,
            EventType::HostTerminalThemeChanged,
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
                themes: Themes::from_config(&slot.configuration),
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
                let mode = ModeView::of(&info);
                let hosts = shown_hosts(&info);
                let dimmed =
                    info.session_ascended == Some(true) || info.session_dimmed == Some(true);
                if info.session_name.is_some() {
                    self.session = info.session_name;
                }
                self.update_views(context.client_id, |view| {
                    view.mode.clone_from(&mode);
                    view.hosts.clone_from(&hosts);
                    view.dimmed = dimmed;
                })
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
            Event::PaneUpdate(manifest) => self.remotes.update(&manifest),
            Event::HostTerminalThemeChanged(mode) => {
                let appearance = match mode {
                    HostTerminalThemeMode::Light => Appearance::Light,
                    HostTerminalThemeMode::Dark => Appearance::Dark,
                };
                match context.client_id {
                    Some(_) => self.replayed_appearance = appearance,
                    None => self.appearance = Some(appearance),
                }
                RenderResponse::All
            }
            Event::Mouse(Mouse::LeftClick(_, column)) => {
                let target = context
                    .client_id
                    .and_then(|client_id| self.views.get(&client_id))
                    .and_then(|view| view.rendered.target_at(column));
                match target {
                    Some(Target::Tab(position)) => switch_tab_to(position as u32 + 1),
                    Some(Target::Host) => focus_host_session(),
                    None => {}
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
        let themes = match (self.permission, &slot.themes) {
            (Some(PermissionStatus::Denied), _) => return notice("permissions denied", cols),
            (_, Err(error)) => return notice(&error.to_string(), cols),
            (_, Ok(themes)) => themes,
        };
        let view = self.views.entry(client_id).or_default();
        let tabs: Vec<Tab> = view
            .tabs
            .iter()
            .map(|tab| Tab {
                remote: self.remotes.host(tab),
                ..tab.clone()
            })
            .collect();
        view.rendered = bar::render(
            &Bar {
                mode: view.mode.shown(),
                session: self.session.as_deref(),
                hosts: &view.hosts,
                tabs: &tabs,
                usage: self.meter.usage(),
            },
            themes.get(
                self.appearance.unwrap_or(self.replayed_appearance),
                view.dimmed,
            ),
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

/// Outside host fullscreen the host's own bar stays visible above this one and
/// already names the host session.
fn shown_hosts(info: &ModeInfo) -> Vec<String> {
    if info.host_fullscreen == Some(true) {
        info.session_ancestry.clone()
    } else {
        Vec::new()
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
        remote: None,
    }
}
