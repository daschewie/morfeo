
package memory

import "lib:emu"

RAM :: struct {
    read8:   proc(^RAM, u32)-> u8 ,
    write8:  proc(^RAM, u32,   u8),
    delete:  proc(^RAM           ),
    read:    proc(^RAM, emu.Request_Size, u32)-> u32 ,
    write:   proc(^RAM, emu.Request_Size, u32,   u32),

    name:   string,
    data:   [dynamic]u8,
    size:   int
}

ram_read :: #force_inline proc(ram: ^RAM, mode: emu.Request_Size, addr: u32) -> (val: u32) {
    switch mode {
    case .bits_8: 
        val = cast(u32) ram.data[addr]
    case .bits_16:
        ptr := transmute(^u16be) &ram.data[addr]
        val  = cast(u32) ptr^
    case .bits_32:
        ptr := transmute(^u32be) &ram.data[addr]
        val  = cast(u32) ptr^
    }
    return
}

ram_write :: #force_inline proc(ram: ^RAM, mode: emu.Request_Size, addr, val: u32) {
    switch mode {
    case .bits_8: 
        ram.data[addr] = cast(u8) val
    case .bits_16:
        (transmute(^u16be) &ram.data[addr])^ = cast(u16be) val
    case .bits_32:
        (transmute(^u32be) &ram.data[addr])^ = cast(u32be) val
    }
    return
}

read8 :: #force_inline proc(ram: ^RAM, addr: u32) -> u8 {
    return ram.data[addr]
}

write8 :: #force_inline proc(ram: ^RAM, addr: u32, val: u8) {
    ram.data[addr] = val
    return
}

make_ram :: proc(name: string, size: int) -> ^RAM {

    ram       := new(RAM)
    ram.name   = name
    ram.read8  = ram_read8
    ram.write8 = ram_write8
    ram.delete = ram_delete
    ram.read   = ram_read
    ram.write  = ram_write
    ram.data   = make([dynamic]u8,     size+3)
    ram.size   = size

    //g         := RAM_Ram{ram = ram}
    return ram
}

ram_delete :: proc(ram: ^RAM) {
    delete(ram.data)
    free(ram)
    return
}

ram_read8 :: proc(ram: ^RAM, addr: u32) -> u8 {
    return ram.data[addr]
}

ram_write8 :: proc(ram: ^RAM, addr: u32, val: u8) {
    ram.data[addr] = val
    return
}
