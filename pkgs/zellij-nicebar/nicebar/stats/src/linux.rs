use std::fs;
use std::process::Command;

use nicebar_core::sample::{CpuTicks, Sample, mean};

pub fn sample() -> Sample {
    Sample {
        cpu: cpu(),
        mem: memory(),
        gpu: gpu(),
    }
}

fn cpu() -> Option<CpuTicks> {
    parse_cpu(&fs::read_to_string("/proc/stat").ok()?)
}

fn parse_cpu(stat: &str) -> Option<CpuTicks> {
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
    Some(CpuTicks {
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

fn gpu() -> Option<f64> {
    mean(drm().chain(nvidia()))
}

/// amdgpu (and some other DRM drivers) expose utilization in sysfs.
fn drm() -> impl Iterator<Item = f64> {
    let is_card = |name: &str| {
        name.strip_prefix("card")
            .is_some_and(|n| !n.is_empty() && n.bytes().all(|b| b.is_ascii_digit()))
    };
    fs::read_dir("/sys/class/drm")
        .into_iter()
        .flatten()
        .flatten()
        .filter(move |entry| is_card(&entry.file_name().to_string_lossy()))
        .filter_map(|entry| {
            fs::read_to_string(entry.path().join("device/gpu_busy_percent"))
                .ok()?
                .trim()
                .parse()
                .ok()
        })
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
