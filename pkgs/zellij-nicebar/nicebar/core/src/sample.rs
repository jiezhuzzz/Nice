use std::fmt;
use std::str::FromStr;

/// Cumulative CPU time since boot. The helper reports raw counters and the
/// plugin diffs consecutive readings, so the helper never has to sleep between
/// two samples itself.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CpuTicks {
    pub busy: u64,
    pub total: u64,
}

impl CpuTicks {
    pub fn usage_since(self, earlier: CpuTicks) -> Option<f64> {
        let total = self.total.checked_sub(earlier.total).filter(|&t| t > 0)?;
        let busy = self.busy.checked_sub(earlier.busy)?;
        Some((busy as f64 / total as f64 * 100.0).min(100.0))
    }
}

/// One line of `nicebar-stats` output, e.g. `cpu=812/9204 mem=63.2 gpu=12.0`.
#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct Sample {
    pub cpu: Option<CpuTicks>,
    pub mem: Option<f64>,
    pub gpu: Option<f64>,
}

impl fmt::Display for Sample {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut fields = Vec::with_capacity(3);
        if let Some(CpuTicks { busy, total }) = self.cpu {
            fields.push(format!("cpu={busy}/{total}"));
        }
        if let Some(mem) = self.mem {
            fields.push(format!("mem={mem:.1}"));
        }
        if let Some(gpu) = self.gpu {
            fields.push(format!("gpu={gpu:.1}"));
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
            match key {
                "cpu" => {
                    let (busy, total) = value.split_once('/').ok_or_else(malformed)?;
                    sample.cpu = Some(CpuTicks {
                        busy: busy.parse().map_err(|_| malformed())?,
                        total: total.parse().map_err(|_| malformed())?,
                    });
                }
                "mem" => sample.mem = Some(value.parse().map_err(|_| malformed())?),
                "gpu" => sample.gpu = Some(value.parse().map_err(|_| malformed())?),
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
    last_cpu: Option<CpuTicks>,
    usage: Usage,
}

impl Meter {
    pub fn record(&mut self, sample: Sample) {
        let cpu = sample
            .cpu
            .zip(self.last_cpu)
            .and_then(|(now, before)| now.usage_since(before));
        self.last_cpu = sample.cpu;
        self.usage = Usage {
            cpu,
            mem: sample.mem,
            gpu: sample.gpu,
        };
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
