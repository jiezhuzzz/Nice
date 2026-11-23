use std::mem::{self, MaybeUninit};

use nicebar_core::sample::{Gpu, Sample, Ticks, mean};
use objc2_core_foundation::{CFDictionary, CFNumber, CFRetained, CFString, CFType, Type};
use objc2_io_kit::{
    IOIteratorNext, IOObjectRelease, IORegistryEntryCreateCFProperty, IOServiceGetMatchingServices,
    IOServiceMatching, io_iterator_t, kIOMainPortDefault,
};

// libc deprecates its binding in favour of the mach2 crate, which lacks the
// host statistics calls used here.
unsafe extern "C" {
    safe fn mach_host_self() -> libc::mach_port_t;
}

pub fn sample() -> Sample {
    let host = mach_host_self();
    Sample {
        cpu: cpu(host),
        mem: memory(host),
        gpu: gpu().map(Gpu::Percent),
    }
}

fn cpu(host: libc::mach_port_t) -> Option<Ticks> {
    let mut info = MaybeUninit::<libc::host_cpu_load_info>::uninit();
    let mut count = libc::HOST_CPU_LOAD_INFO_COUNT;
    // SAFETY: `info` is a host_cpu_load_info and `count` is its size in
    // integer_t units, as HOST_CPU_LOAD_INFO requires.
    let status = unsafe {
        libc::host_statistics(
            host,
            libc::HOST_CPU_LOAD_INFO,
            info.as_mut_ptr().cast(),
            &mut count,
        )
    };
    if status != libc::KERN_SUCCESS {
        return None;
    }
    // SAFETY: the kernel filled the struct on success.
    let ticks = unsafe { info.assume_init() }.cpu_ticks.map(u64::from);
    let total = ticks.iter().sum();
    Some(Ticks {
        busy: total - ticks[libc::CPU_STATE_IDLE as usize],
        total,
    })
}

/// Matches Activity Monitor's "Memory Used": app memory (anonymous pages that
/// are not purgeable), plus wired and compressed memory.
fn memory(host: libc::mach_port_t) -> Option<f64> {
    let mut vm = MaybeUninit::<libc::vm_statistics64>::zeroed();
    let mut count = libc::HOST_VM_INFO64_COUNT;
    // SAFETY: `vm` is a vm_statistics64 and `count` is its size in integer_t
    // units, as HOST_VM_INFO64 requires. Older kernels fill a prefix and lower
    // `count`; the zeroed tail is never read.
    let status = unsafe {
        libc::host_statistics64(
            host,
            libc::HOST_VM_INFO64,
            vm.as_mut_ptr().cast(),
            &mut count,
        )
    };
    if status != libc::KERN_SUCCESS {
        return None;
    }
    // SAFETY: zero-initialised and partly filled by the kernel.
    let vm = unsafe { vm.assume_init() };
    let pages = u64::from(vm.internal_page_count).saturating_sub(u64::from(vm.purgeable_count))
        + u64::from(vm.wire_count)
        + u64::from(vm.compressor_page_count);
    // SAFETY: sysconf has no preconditions.
    let page_size = u64::try_from(unsafe { libc::sysconf(libc::_SC_PAGESIZE) }).ok()?;
    Some((pages * page_size) as f64 / physical_memory()? as f64 * 100.0)
}

fn physical_memory() -> Option<u64> {
    let mut bytes = 0u64;
    let mut size = mem::size_of::<u64>();
    // SAFETY: hw.memsize is a 64-bit integer and `size` matches the buffer.
    let status = unsafe {
        libc::sysctlbyname(
            c"hw.memsize".as_ptr(),
            (&raw mut bytes).cast(),
            &mut size,
            std::ptr::null_mut(),
            0,
        )
    };
    (status == 0).then_some(bytes)
}

/// Every IOAccelerator publishes "Device Utilization %" under its
/// PerformanceStatistics property; `ioreg -c IOAccelerator` shows the same
/// data without the cost of spawning it.
fn gpu() -> Option<f64> {
    // SAFETY: the class name is a valid C string.
    let matching = unsafe { IOServiceMatching(c"IOAccelerator".as_ptr()) }?;
    let matching: &CFDictionary = &matching;
    let mut iterator: io_iterator_t = 0;
    // SAFETY: the matching dictionary is consumed and `iterator` receives a
    // handle that is released below.
    let status = unsafe {
        IOServiceGetMatchingServices(kIOMainPortDefault, Some(matching.retain()), &mut iterator)
    };
    if status != libc::KERN_SUCCESS {
        return None;
    }
    let statistics_key = CFString::from_static_str("PerformanceStatistics");
    let utilization_key = CFString::from_static_str("Device Utilization %");
    let mut readings = Vec::new();
    loop {
        let service = IOIteratorNext(iterator);
        if service == 0 {
            break;
        }
        // SAFETY: `service` is a live registry entry until released below.
        let statistics =
            unsafe { IORegistryEntryCreateCFProperty(service, Some(&statistics_key), None, 0) };
        IOObjectRelease(service);
        if let Some(percent) = statistics.and_then(|s| utilization(s, &utilization_key)) {
            readings.push(percent);
        }
    }
    IOObjectRelease(iterator);
    mean(readings)
}

fn utilization(statistics: CFRetained<CFType>, key: &CFString) -> Option<f64> {
    let statistics = statistics.downcast::<CFDictionary>().ok()?;
    // SAFETY: IOKit property dictionaries are keyed by CFString.
    let statistics: CFRetained<CFDictionary<CFString, CFType>> =
        unsafe { CFRetained::cast_unchecked(statistics) };
    statistics.get(key)?.downcast::<CFNumber>().ok()?.as_f64()
}
