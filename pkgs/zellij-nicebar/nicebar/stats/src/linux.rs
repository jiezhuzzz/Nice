use std::fs;
use std::path::PathBuf;
use std::process::Command;

use nicebar_core::sample::{Gpu, Sample, Ticks, mean};

pub fn sample() -> Sample {
    Sample {
        cpu: cpu(),
        mem: memory(),
        gpu: gpu(),
    }
}

fn cpu() -> Option<Ticks> {
    parse_cpu(&fs::read_to_string("/proc/stat").ok()?)
}

fn parse_cpu(stat: &str) -> Option<Ticks> {
    let ticks = stat.lines().next()?.strip_prefix("cpu ")?;
    // user nice system idle iowait irq softirq steal; guest time is already
    // counted in user and nice.
    let ticks: Vec<u64> = ticks
        .split_whitespace()
        .take(8)
        .map(str::parse)
        .collect::<Result<_, _>>()
        .ok()?;
    let total = ticks.iter().sum();
    let idle = ticks.get(3)? + ticks.get(4).unwrap_or(&0);
    Some(Ticks {
        busy: total - idle,
        total,
    })
}

fn memory() -> Option<f64> {
    parse_memory(&fs::read_to_string("/proc/meminfo").ok()?)
}

fn parse_memory(meminfo: &str) -> Option<f64> {
    let kib = |field: &str| {
        meminfo
            .lines()
            .find_map(|line| line.strip_prefix(field))?
            .trim()
            .strip_suffix("kB")?
            .trim()
            .parse::<f64>()
            .ok()
    };
    let total = kib("MemTotal:")?;
    let available = kib("MemAvailable:")?;
    Some((total - available) / total * 100.0)
}

fn gpu() -> Option<Gpu> {
    mean(drm().chain(nvidia()))
        .map(Gpu::Percent)
        .or_else(|| xe().map(Gpu::Ticks))
}

fn cards() -> impl Iterator<Item = PathBuf> {
    let is_card = |name: &str| {
        name.strip_prefix("card")
            .is_some_and(|n| !n.is_empty() && n.bytes().all(|b| b.is_ascii_digit()))
    };
    fs::read_dir("/sys/class/drm")
        .into_iter()
        .flatten()
        .flatten()
        .filter(move |entry| is_card(&entry.file_name().to_string_lossy()))
        .map(|entry| entry.path().join("device"))
}

fn subdirs(dir: PathBuf, prefix: &'static str) -> impl Iterator<Item = PathBuf> {
    fs::read_dir(dir)
        .into_iter()
        .flatten()
        .flatten()
        .filter(move |entry| entry.file_name().to_string_lossy().starts_with(prefix))
        .map(|entry| entry.path())
}

/// amdgpu (and some other DRM drivers) expose utilization in sysfs.
fn drm() -> impl Iterator<Item = f64> {
    cards().filter_map(|device| {
        fs::read_to_string(device.join("gpu_busy_percent"))
            .ok()?
            .trim()
            .parse()
            .ok()
    })
}

/// xe's engine counters are perf events, which need CAP_PERFMON, so the time
/// its render GTs spend out of the C6 power state stands in for busy time.
fn xe() -> Option<Ticks> {
    let idle_ms: Vec<u64> = cards()
        .flat_map(|device| subdirs(device, "tile"))
        .flat_map(|tile| subdirs(tile, "gt"))
        .map(|gt| gt.join("gtidle"))
        .filter(|gtidle| {
            fs::read_to_string(gtidle.join("name")).is_ok_and(|name| name.trim().ends_with("-rc"))
        })
        .filter_map(|gtidle| {
            fs::read_to_string(gtidle.join("idle_residency_ms"))
                .ok()?
                .trim()
                .parse()
                .ok()
        })
        .collect();
    if idle_ms.is_empty() {
        return None;
    }
    let total = monotonic_ms()? * idle_ms.len() as u64;
    Some(Ticks {
        busy: total.saturating_sub(idle_ms.iter().sum()),
        total,
    })
}

fn monotonic_ms() -> Option<u64> {
    let mut now = libc::timespec {
        tv_sec: 0,
        tv_nsec: 0,
    };
    // SAFETY: `now` is a valid timespec for clock_gettime to fill.
    if unsafe { libc::clock_gettime(libc::CLOCK_MONOTONIC, &mut now) } != 0 {
        return None;
    }
    let secs = u64::try_from(now.tv_sec).ok()?;
    let nanos = u64::try_from(now.tv_nsec).ok()?;
    Some(secs * 1000 + nanos / 1_000_000)
}

/// NVIDIA has no sysfs counter; its tool is used when the driver installed it.
fn nvidia() -> Vec<f64> {
    let output = Command::new("nvidia-smi")
        .args([
            "--query-gpu=utilization.gpu",
            "--format=csv,noheader,nounits",
        ])
        .output();
    let Ok(output) = output else {
        return Vec::new();
    };
    if !output.status.success() {
        return Vec::new();
    }
    String::from_utf8_lossy(&output.stdout)
        .lines()
        .filter_map(|line| line.trim().parse().ok())
        .collect()
}
