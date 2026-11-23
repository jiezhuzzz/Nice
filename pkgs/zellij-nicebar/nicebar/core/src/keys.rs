#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Key {
    pub modifiers: usize,
    pub named: bool,
    pub name: String,
}

pub fn preferred(mut keys: Vec<Key>) -> Option<String> {
    let fewest = keys.iter().map(|key| key.modifiers).min()?;
    keys.retain(|key| key.modifiers == fewest);
    keys.sort_by_cached_key(|key| {
        (
            key.named,
            key.name.chars().any(char::is_uppercase),
            key.name.clone(),
        )
    });
    let digits: Option<Vec<u32>> = keys.iter().map(digit).collect();
    match digits.as_deref() {
        Some([first, .., last]) if (last - first) as usize == keys.len() - 1 => {
            Some(format!("{first}-{last}"))
        }
        _ => keys.into_iter().next().map(|key| key.name),
    }
}

fn digit(key: &Key) -> Option<u32> {
    let mut chars = key.name.chars();
    let digit = chars.next()?.to_digit(10)?;
    (!key.named && chars.next().is_none()).then_some(digit)
}
