use std::collections::BTreeMap;
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Rgb(pub u8, pub u8, pub u8);

impl Rgb {
    pub fn from_hex(hex: &str) -> Option<Rgb> {
        let digits = hex.strip_prefix('#')?;
        if digits.len() != 6 || !digits.bytes().all(|b| b.is_ascii_hexdigit()) {
            return None;
        }
        let channel = |i: usize| u8::from_str_radix(&digits[i..i + 2], 16).ok();
        Some(Rgb(channel(0)?, channel(2)?, channel(4)?))
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ThemeError {
    Missing(String),
    Invalid(String),
}

impl fmt::Display for ThemeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ThemeError::Missing(key) => write!(f, "missing color `{key}`"),
            ThemeError::Invalid(key) => write!(f, "color `{key}` is not #rrggbb"),
        }
    }
}

impl std::error::Error for ThemeError {}

const MODE_PREFIX: &str = "mode_";

/// Which of its two themes the host terminal is showing.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum Appearance {
    Light,
    #[default]
    Dark,
}

impl Appearance {
    fn prefix(self) -> &'static str {
        match self {
            Appearance::Light => "light_",
            Appearance::Dark => "dark_",
        }
    }
}

/// A theme for each appearance, read from the plugin configuration keys under
/// that appearance's prefix (`light_text`, `dark_text`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Themes {
    light: Shades,
    dark: Shades,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct Shades {
    lit: Theme,
    dimmed: Theme,
}

impl Themes {
    pub fn from_config(config: &BTreeMap<String, String>) -> Result<Themes, ThemeError> {
        let shades = |appearance: Appearance| {
            Theme::from_config(config, appearance.prefix()).map(|lit| Shades {
                dimmed: lit.dimmed(),
                lit,
            })
        };
        Ok(Themes {
            light: shades(Appearance::Light)?,
            dark: shades(Appearance::Dark)?,
        })
    }

    pub fn get(&self, appearance: Appearance, dimmed: bool) -> &Theme {
        let shades = match appearance {
            Appearance::Light => &self.light,
            Appearance::Dark => &self.dark,
        };
        if dimmed {
            &shades.dimmed
        } else {
            &shades.lit
        }
    }
}

/// Colors by role. `mode` colors every mode, and `mode_<label>` (e.g.
/// `mode_locked`) overrides it for one mode.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Theme {
    pub text: Rgb,
    pub muted_text: Rgb,
    pub faint_text: Rgb,
    pub ghost_text: Rgb,
    pub accent: Rgb,
    pub pill_bg: Rgb,
    pub warn: Rgb,
    pub crit: Rgb,
    mode: Rgb,
    mode_overrides: BTreeMap<String, Rgb>,
}

impl Theme {
    fn from_config(config: &BTreeMap<String, String>, prefix: &str) -> Result<Theme, ThemeError> {
        let parse = |key: &str, value: &str| {
            Rgb::from_hex(value).ok_or_else(|| ThemeError::Invalid(key.to_owned()))
        };
        let required = |role: &str| {
            let key = format!("{prefix}{role}");
            match config.get(&key) {
                Some(value) => parse(&key, value),
                None => Err(ThemeError::Missing(key)),
            }
        };
        let mode_prefix = format!("{prefix}{MODE_PREFIX}");
        let mode_overrides = config
            .iter()
            .filter_map(|(key, value)| Some((key, key.strip_prefix(mode_prefix.as_str())?, value)))
            .map(|(key, label, value)| Ok((label.to_ascii_uppercase(), parse(key, value)?)))
            .collect::<Result<_, _>>()?;
        Ok(Theme {
            text: required("text")?,
            muted_text: required("muted_text")?,
            faint_text: required("faint_text")?,
            ghost_text: required("ghost_text")?,
            accent: required("accent")?,
            pill_bg: required("pill_bg")?,
            warn: required("warn")?,
            crit: required("crit")?,
            mode: required("mode")?,
            mode_overrides,
        })
    }

    pub fn mode(&self, label: &str) -> Rgb {
        self.mode_overrides.get(label).copied().unwrap_or(self.mode)
    }

    /// `pill_bg` is kept, since the pill's caps are drawn in it to match its
    /// fill.
    fn dimmed(&self) -> Theme {
        let faint = self.faint_text;
        Theme {
            text: faint,
            muted_text: faint,
            accent: faint,
            warn: faint,
            crit: faint,
            mode: faint,
            mode_overrides: BTreeMap::new(),
            ..self.clone()
        }
    }
}
