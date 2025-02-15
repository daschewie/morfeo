package gpu

import "core:time"

import "lib:emu"

GPU :: struct {
    read:    proc(^GPU, emu.Request_Size, u32, u32, emu.Mode) -> u32,
    write:   proc(^GPU, emu.Request_Size, u32, u32, u32,    emu.Mode),
    read8:   proc(^GPU, u32) -> u8,
    write8:  proc(^GPU, u32,    u8),
    delete:  proc(^GPU            ),
    render:  proc(^GPU            ),

    name:               string,     // textual name of instance
    id:                 int,        // id of instance

    TFB:     ^[1024*768]u32,        // text    framebuffer
    BM0FB:   ^[1024*768]u32,        // bitmap0 framebuffer
    BM1FB:   ^[1024*768]u32,        // bitmap1 framebuffer

    gpu_enabled:       bool,
    text_enabled:      bool,
    graphic_enabled:   bool,
    bitmap_enabled:    bool,
    border_enabled:    bool,
    sprite_enabled:    bool,
    tile_enabled:      bool,

    border_color_b:    u8,
    border_color_g:    u8,
    border_color_r:    u8,
    border_x_size:     i32,
    border_y_size:     i32,

    bg_color_b:        u8,
    bg_color_g:        u8,
    bg_color_r:        u8,

    screen_resized:    bool,
    screen_x_size:     i32,
    screen_y_size:     i32,

    cursor_enabled:    bool,
    cursor_rate:       i32,
    cursor_visible:    bool,     // set by timer in main GUI, for blinking
    cursor_x:          u32,
    cursor_y:          u32,
    cursor_character:  u32,
    cursor_fg:         u32,
    cursor_bg:         u32,

    bm0_enabled:           bool,
    bm0_collision_enabled: bool,
    bm0_pointer:           u32,
    bm0_lut:               u32,

    bm1_enabled:           bool,
    bm1_collision_enabled: bool,
    bm1_pointer:           u32,
    bm1_lut:               u32,

    background:        [3]u8,    // r, g, b
    frames:            u32,      // number of generated frames, for TIMER*
    delay:             time.Duration,      // number of milliseconds to wait between frames
                                           // 16 for 60Hz, 14 for 70Hz
    last_tick:         time.Tick,          // when last tick was made

    model: union {GPU_Vicky2, GPU_Vicky3}
}

// not used - it is a separated approach, alternative to vtable
// when gpu.render(gpu) is called (or simply render, but we need
// a way to differentiate calls like 'read')
//
// so read_gpu :: proc {switch g in gpu...}
//    read_bus :: proc {switch b in bus...}
//    read     :: proc {read_bus, read_gpu} ?

render :: #force_inline proc(gpu: ^GPU) {
    switch g in gpu.model {
    case GPU_Vicky3: vicky3_render_text(g)
    case GPU_Vicky2: 
    }
}

