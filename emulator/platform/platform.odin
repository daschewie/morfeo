package platform

import "emulator:ata"
import "emulator:bus"
import "emulator:cpu"
import "emulator:gpu"
import "emulator:pic"
import "emulator:ps2"
import "emulator:rtc"
import "emulator:memory"

import "core:fmt"
import "core:log"

Platform   :: struct { 
    delete: proc(^Platform),

    cpu:     ^cpu.CPU,
    bus:     ^bus.Bus,
}
