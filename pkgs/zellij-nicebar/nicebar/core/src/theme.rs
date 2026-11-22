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
    Missing(&'static str),
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

/// Colors by role, read from the plugin configuration. `mode` colors every
/// mode, and `mode_<label>` (e.g. `mode_locked`) overrides it for one mode.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Theme {
    pub text: Rgb,
    pub muted_text: Rgb,
    pub accent_text: Rgb,
    pub session_bg: Rgb,
    pub tab_bg: Rgb,
    pub tab_active_bg: Rgb,
    pub stats_bg: Rgb,
    pub warn: Rgb,
    pub crit: Rgb,
    mode: Rgb,
    mode_overrides: BTreeMap<String, Rgb>,
}

impl Theme {
    pub fn from_config(config: &BTreeMap<String, String>) -> Result<Theme, ThemeError> {
        let parse = |key: &str, value: &str| {
            Rgb::from_hex(value).ok_or_else(|| ThemeError::Invalid(key.to_owned()))
        };
        let required =
            |key: &'static str| parse(key, config.get(key).ok_or(ThemeError::Missing(key))?);
        let mode_overrides = config
            .iter()
            .filter_map(|(key, value)| Some((key, key.strip_prefix(MODE_PREFIX)?, value)))
            .map(|(key, label, value)| Ok((label.to_ascii_uppercase(), parse(key, value)?)))
            .collect::<Result<_, _>>()?;
        Ok(Theme {
            text: required("text")?,
            muted_text: required("muted_text")?,
            accent_text: required("accent_text")?,
            session_bg: required("session_bg")?,
            tab_bg: required("tab_bg")?,
            tab_active_bg: required("tab_active_bg")?,
            stats_bg: required("stats_bg")?,
            warn: required("warn")?,
            crit: required("crit")?,
            mode: required("mode")?,
            mode_overrides,
        })
    }

    pub fn mode(&self, label: &str) -> Rgb {
        self.mode_overrides.get(label).copied().unwrap_or(self.mode)
    }
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;

    pub(crate) fn config() -> BTreeMap<String, String> {
        [
            ("text", "#cdd6f4"),
            ("accent_text", "#11111b"),
            ("session_bg", "#45475a"),
            ("tab_bg", "#313244"),
            ("muted_text", "#a6adc8"),
            ("tab_active_bg", "#fab387"),
            ("stats_bg", "#313244"),
            ("warn", "#f9e2af"),
            ("crit", "#f38ba8"),
            ("mode", "#89b4fa"),
            ("mode_locked", "#f38ba8"),
        ]
        .into_iter()
        .map(|(k, v)| (k.to_owned(), v.to_owned()))
        .collect()
    }

    #[test]
    fn parses_hex_colors() {
        assert_eq!(Rgb::from_hex("#fab387"), Some(Rgb(0xfa, 0xb3, 0x87)));
        for bad in [
            "fab387", "#fab38", "#fab3877", "#gggggg", "#fäb387", "#+f+f+f",
        ] {
            assert_eq!(Rgb::from_hex(bad), None, "{bad}");
        }
    }

    #[test]
    fn mode_overrides_fall_back_to_the_base_mode_color() {
        let theme = Theme::from_config(&config()).unwrap();
        assert_eq!(theme.mode("LOCKED"), Rgb(0xf3, 0x8b, 0xa8));
        assert_eq!(theme.mode("PANE"), Rgb(0x89, 0xb4, 0xfa));
    }

    #[test]
    fn reports_the_offending_key() {
        let mut config = config();
        config.remove("tab_bg");
        assert_eq!(
            Theme::from_config(&config),
            Err(ThemeError::Missing("tab_bg"))
        );
        let mut config = self::config();
        config.insert("mode_tab".into(), "orange".into());
        assert_eq!(
            Theme::from_config(&config),
            Err(ThemeError::Invalid("mode_tab".into()))
        );
    }
}
