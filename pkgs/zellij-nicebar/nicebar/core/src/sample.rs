use std::fmt;
use std::str::FromStr;

/// Cumulative busy and total time. The helper reports raw counters and the
/// plugin diffs consecutive readings, so the helper never has to sleep between
/// two samples itself.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Ticks {
    pub busy: u64,
    pub total: u64,
}

impl Ticks {
    pub fn usage_since(self, earlier: Ticks) -> Option<f64> {
        let total = self.total.checked_sub(earlier.total).filter(|&t| t > 0)?;
        let busy = self.busy.checked_sub(earlier.busy)?;
        Some((busy as f64 / total as f64 * 100.0).min(100.0))
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Gpu {
    Percent(f64),
    Ticks(Ticks),
}

/// One line of `nicebar-stats` output, e.g. `cpu=812/9204 mem=63.2 gpu=12.0`
/// or `cpu=812/9204 mem=63.2 gpu=310/2400`.
#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct Sample {
    pub cpu: Option<Ticks>,
    pub mem: Option<f64>,
    pub gpu: Option<Gpu>,
}

impl fmt::Display for Sample {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut fields = Vec::with_capacity(3);
        if let Some(Ticks { busy, total }) = self.cpu {
            fields.push(format!("cpu={busy}/{total}"));
        }
        if let Some(mem) = self.mem {
            fields.push(format!("mem={mem:.1}"));
        }
        match self.gpu {
            Some(Gpu::Percent(gpu)) => fields.push(format!("gpu={gpu:.1}")),
            Some(Gpu::Ticks(Ticks { busy, total })) => fields.push(format!("gpu={busy}/{total}")),
            None => {}
        }
        f.write_str(&fields.join(" "))
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParseSampleError(String);

impl fmt::Display for ParseSampleError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "malformed stats field `{}`", self.0)
    }
}

impl std::error::Error for ParseSampleError {}

impl FromStr for Sample {
    type Err = ParseSampleError;

    fn from_str(line: &str) -> Result<Self, Self::Err> {
        let mut sample = Sample::default();
        for field in line.split_whitespace() {
            let malformed = || ParseSampleError(field.to_owned());
            let (key, value) = field.split_once('=').ok_or_else(malformed)?;
            let ticks = || {
                let (busy, total) = value.split_once('/').ok_or_else(malformed)?;
                Ok(Ticks {
                    busy: busy.parse().map_err(|_| malformed())?,
                    total: total.parse().map_err(|_| malformed())?,
                })
            };
            match key {
                "cpu" => sample.cpu = Some(ticks()?),
                "mem" => sample.mem = Some(value.parse().map_err(|_| malformed())?),
                "gpu" if value.contains('/') => sample.gpu = Some(Gpu::Ticks(ticks()?)),
                "gpu" => {
                    sample.gpu = Some(Gpu::Percent(value.parse().map_err(|_| malformed())?));
                }
                _ => return Err(malformed()),
            }
        }
        Ok(sample)
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct Usage {
    pub cpu: Option<f64>,
    pub mem: Option<f64>,
    pub gpu: Option<f64>,
}

#[derive(Debug, Default)]
pub struct Meter {
    last_cpu: Option<Ticks>,
    last_gpu: Option<Ticks>,
    usage: Usage,
}

impl Meter {
    pub fn record(&mut self, sample: Sample) {
        let since = |now: Option<Ticks>, before: Option<Ticks>| {
            now.zip(before)
                .and_then(|(now, before)| now.usage_since(before))
        };
        let gpu_ticks = match sample.gpu {
            Some(Gpu::Ticks(ticks)) => Some(ticks),
            _ => None,
        };
        let gpu = match sample.gpu {
            Some(Gpu::Percent(percent)) => Some(percent),
            _ => since(gpu_ticks, self.last_gpu),
        };
        self.usage = Usage {
            cpu: since(sample.cpu, self.last_cpu),
            mem: sample.mem,
            gpu,
        };
        self.last_cpu = sample.cpu;
        self.last_gpu = gpu_ticks;
    }

    pub fn clear(&mut self) {
        *self = Self::default();
    }

    pub fn usage(&self) -> Usage {
        self.usage
    }

    pub fn is_priming(&self) -> bool {
        self.last_cpu.is_some() && self.usage.cpu.is_none()
    }
}

pub fn mean(values: impl IntoIterator<Item = f64>) -> Option<f64> {
    let (sum, count) = values
        .into_iter()
        .fold((0.0, 0u32), |(sum, count), value| (sum + value, count + 1));
    (count > 0).then(|| sum / f64::from(count))
}
