/// ssh(1)'s getopt string: each of these letters consumes the rest of its
/// cluster, or the next argument when it ends the cluster.
const TAKES_VALUE: &str = "BbcDEeFIiJLlmOoPpQRSWw";

/// Kept as typed, so a `~/.ssh/config` alias stays an alias.
pub fn destination(command: &[String]) -> Option<&str> {
    let (program, args) = command.split_first()?;
    if program.rsplit('/').next() != Some("ssh") {
        return None;
    }
    let mut args = args.iter();
    while let Some(arg) = args.next() {
        if arg == "--" {
            return args.next().map(|arg| host(arg));
        }
        match arg.strip_prefix('-').filter(|flags| !flags.is_empty()) {
            Some(flags) => {
                if flags.find(|flag| TAKES_VALUE.contains(flag)) == Some(flags.len() - 1) {
                    args.next();
                }
            }
            None => return Some(host(arg)),
        }
    }
    None
}

fn host(destination: &str) -> &str {
    let (authority, uri) = match destination.strip_prefix("ssh://") {
        Some(authority) => (authority, true),
        None => (destination, false),
    };
    let host = authority
        .rsplit_once('@')
        .map_or(authority, |(_, host)| host);
    if uri {
        host.split(':').next().unwrap_or(host)
    } else {
        host
    }
}
