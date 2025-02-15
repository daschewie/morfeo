
package morfeo

import "core:fmt"
import "core:log"
import "core:time"

import "vendor:sdl2"
import "emulator:gpu"
import "emulator:platform"

WINDOW_NAME ::  "morfeo"

GUI :: struct {
    window:      ^sdl2.Window,
    renderer:    ^sdl2.Renderer,
    texture_txt: ^sdl2.Texture,
    texture_bm0: ^sdl2.Texture,
    texture_bm1: ^sdl2.Texture,

    orig_mode:   ^sdl2.DisplayMode,     // for return from fullscreen

    fullscreen:  bool,
    scale_mult:  i32,                   // scale factor, 1 or 2
    x_size:      i32,                   // emulated x screen size
    y_size:      i32,                   // emulated y screen size

    active_gpu:  u8,                    // GPU number

    should_close: bool,
    switch_gpu:   bool,
    current_gpu:  int,
    g:            ^gpu.GPU,             // currently active GPU
    gpu0:         ^gpu.GPU,             // first GPU
    gpu1:         ^gpu.GPU,             // second GPU
}

gui: GUI

create_texture :: proc() -> ^sdl2.Texture {
    texture := sdl2.CreateTexture(
               gui.renderer,
               sdl2.PixelFormatEnum.ARGB8888,
               sdl2.TextureAccess.STREAMING, 
               gui.x_size, 
               gui.y_size
    )
    if texture == nil {
        error := sdl2.GetError()
        log.errorf("sdl2.CreateTexture failed: %s", error)
        return nil
    }
    err := sdl2.SetTextureBlendMode(texture, sdl2.BlendMode.BLEND)
    if err != 0 {
        error := sdl2.GetError()
        log.errorf("sdl2.SetTextureBlendMode failed: %s", error)
    }
    return texture
}

init_sdl :: proc(p: ^platform.Platform, gpu_number: int = 1) -> (ok: bool) {
    gui = GUI{}

    // XXX: parametrize it and fetch default resolutions from current gpu
    gui.x_size      = 800
    gui.y_size      = 600
    gui.scale_mult  = 2
    gui.fullscreen  = false

    // set initial parameters and force refresh in render_gui() by switch_gpu = 1
    // current_gpu number shuffle is a trick for switch_gpu routine at first run
    gui.gpu0        = p.bus.gpu0
    gui.gpu1        = p.bus.gpu1
    gui.current_gpu = 1                if gpu_number == 0      else 0
    gui.g           = p.bus.gpu0       if gui.current_gpu == 0 else p.bus.gpu1
    gui.switch_gpu  = true

    // init
    if sdl_res := sdl2.Init(sdl2.INIT_EVERYTHING); sdl_res < 0 {
        log.errorf("sdl2.init returned %v.", sdl_res)
        return false
    }

    // windows
    gui.window = sdl2.CreateWindow(
                 fmt.ctprintf("morfeo: gpu%d", gui.current_gpu),
                 sdl2.WINDOWPOS_UNDEFINED, 
                 sdl2.WINDOWPOS_UNDEFINED, 
                 gui.x_size * gui.scale_mult, 
                 gui.y_size * gui.scale_mult,
                 sdl2.WINDOW_SHOWN
                 //sdl2.WINDOW_SHOWN|sdl2.WINDOW_OPENGL
    )
    if gui.window == nil {
        log.errorf("sdl2.CreateWindow failed.")
        return false
    }

    // preserve original resolution
    display_index := sdl2.GetWindowDisplayIndex(gui.window)

    gui.orig_mode = new(sdl2.DisplayMode)
    if sdl_res := sdl2.GetCurrentDisplayMode(display_index, gui.orig_mode); sdl_res < 0 {
        log.errorf("sdl2.GetCurrentDisplayMode returned %v.", sdl_res)
        return false
    }

    ok = new_renderer_and_texture()
    return ok
}

new_renderer_and_texture :: proc() -> (ok: bool) {
    gui.renderer = sdl2.CreateRenderer(gui.window, -1, {.ACCELERATED})
    if gui.renderer == nil {
        log.errorf("sdl2.CreateRenderer failed.")
        return false
    }

    gui.texture_txt = create_texture()
    gui.texture_bm0 = create_texture()
    gui.texture_bm1 = create_texture()

    // XXX workaround - I don't get that
    sdl2.SetTextureBlendMode(gui.texture_bm0, sdl2.BlendMode.NONE)

    sdl2.SetHint("SDL_HINT_RENDER_BATCHING", "1")
    
    return true
}

update_window_size :: proc() {
    scale: i32

    // exit from fullscreen if necessary
    if gui.fullscreen {
            //gui.window.SetDisplayMode(orig_mode)
            //gui.window.SetFullscreen(0)
            scale = 1                       // we do not scale in fullscreen
    } else {
            scale = gui.scale_mult
    }

    sdl2.DestroyRenderer(gui.renderer)
    sdl2.DestroyTexture(gui.texture_txt)
    sdl2.DestroyTexture(gui.texture_bm0)
    sdl2.DestroyTexture(gui.texture_bm1)

    sdl2.SetWindowSize(gui.window, gui.x_size * scale, gui.y_size * scale)

    _ = new_renderer_and_texture()

    // return to fullscreen if necessary
    /*
    if gui.fullscreen {
            sdl.SetWindowFullscreen(gui.window)
    }
    */
}

// XXX - move scaling code into gpu recalculate window to avoid unneccessary multiplication
draw_border :: proc(g: ^gpu.GPU) {
    sdl2.SetRenderDrawColor(gui.renderer, g.border_color_r, g.border_color_g, g.border_color_b, sdl2.ALPHA_OPAQUE)
    if gui.fullscreen {
        x := [?]sdl2.Rect {
                    sdl2.Rect{0, 
                              0, 
                              gui.x_size, 
                              g.border_y_size},

                    sdl2.Rect{0, 
                              gui.y_size - g.border_y_size, 
                              gui.x_size, 
                              g.border_y_size},

                    sdl2.Rect{0, 
                              g.border_y_size,  
                              g.border_x_size, 
                              gui.y_size - g.border_y_size},

                    sdl2.Rect{gui.x_size - g.border_x_size, 
                              g.border_y_size, 
                              g.border_x_size, 
                              gui.y_size - g.border_y_size}
                }
        sdl2.RenderFillRects(gui.renderer, raw_data(x[:]), 4)

    } else {
        x :=  [?]sdl2.Rect{
                    sdl2.Rect{0, 
                              0, 
                              gui.x_size                   * gui.scale_mult, 
                              g.border_y_size              * gui.scale_mult},

                    sdl2.Rect{0, 
                              (gui.y_size-g.border_y_size) * gui.scale_mult, 
                              gui.x_size                   * gui.scale_mult, 
                              g.border_y_size              * gui.scale_mult},

                    sdl2.Rect{0,
                              g.border_y_size              * gui.scale_mult,  
                              g.border_x_size              * gui.scale_mult, 
                              (gui.y_size-g.border_y_size) * gui.scale_mult},

                    sdl2.Rect{(gui.x_size-g.border_x_size) * gui.scale_mult, 
                              g.border_y_size              * gui.scale_mult, 
                              g.border_x_size              * gui.scale_mult, 
                              (gui.y_size-g.border_y_size) * gui.scale_mult}
                }
        sdl2.RenderFillRects(gui.renderer, raw_data(x[:]), 4)
    }
    return
}

cleanup_sdl :: proc() {
        sdl2.DestroyWindow(gui.window)
        sdl2.DestroyRenderer(gui.renderer)
        sdl2.DestroyTexture(gui.texture_txt)
        sdl2.DestroyTexture(gui.texture_bm0)
        sdl2.DestroyTexture(gui.texture_bm1)
        sdl2.QuitSubSystem(sdl2.INIT_EVERYTHING)
        sdl2.Quit()
}

process_input :: proc(p: ^platform.Platform) {
    e: sdl2.Event

    for sdl2.PollEvent(&e) {
        #partial switch(e.type) {
        case .QUIT:
            gui.should_close = true
        case .KEYDOWN:
            #partial switch(e.key.keysym.sym) {
            case .F12:
                gui.should_close = true
            case .F8:
                gui.switch_gpu = true
            case:
                send_key_to_ps2(p, e.key.keysym.scancode, e.type)
            }
        case .KEYUP:
            #partial switch(e.key.keysym.sym) {
            case .F12: // mask key
            case .F8:  // mask key
            case: 
                send_key_to_ps2(p, e.key.keysym.scancode, e.type)
            }
        }
    }
}

render_gui :: proc(p: ^platform.Platform) -> bool {

        // Step 1: process keyboard in (XXX: do it - mouse)
        process_input(p)

        // Step 2: handle GPU switching
        if gui.switch_gpu {
            gui.current_gpu        = 1        if gui.current_gpu == 0 else 0
            gui.g                  = gui.gpu0 if gui.current_gpu == 0 else gui.gpu1
            gui.switch_gpu         = false
            gui.g.screen_resized   = true
            sdl2.SetWindowTitle(gui.window, fmt.ctprintf("morfeo: gpu%d", gui.current_gpu))
        }

        // Step 3: handle screen resize
        if gui.g.screen_resized {
                gui.x_size = gui.g.screen_x_size
                gui.y_size = gui.g.screen_y_size

                gui.g.screen_resized = false
                update_window_size()
        }

        // Step 4: call active GPU to render things
        //         XXX: support two windows and rendering of two monitors at once
        if time.tick_since(gui.gpu0.last_tick) >= gui.gpu0.delay {
            if gui.current_gpu   == 0 do gui.g->render()
            gui.gpu0.frames      += 1
            gui.gpu0.last_tick    = time.tick_now()
        }

        if time.tick_since(gui.gpu1.last_tick) >= gui.gpu1.delay {
            if gui.current_gpu   == 1 do gui.g->render()
            gui.gpu1.frames      += 1
            gui.gpu1.last_tick    = time.tick_now()
        }

        // Step 5 : draw to screen
        // Step 5a: background
        //
        sdl2.SetRenderDrawColor(gui.renderer, gui.g.bg_color_r,
                                              gui.g.bg_color_g,
                                              gui.g.bg_color_b,
                                              sdl2.ALPHA_OPAQUE)
        sdl2.RenderClear(gui.renderer)

        // Step 5b: bitmap 0 and 1
        //
        if gui.g.bitmap_enabled & gui.g.graphic_enabled {
            if gui.g.bm0_enabled {
                sdl2.UpdateTexture(gui.texture_bm0, nil, gui.g.BM0FB, gui.x_size*4)
                sdl2.RenderCopy(gui.renderer, gui.texture_bm0, nil, nil)
            }
            if gui.g.bm1_enabled {
                sdl2.UpdateTexture(gui.texture_bm1, nil, gui.g.BM1FB, gui.x_size*4)
                sdl2.RenderCopy(gui.renderer, gui.texture_bm1, nil, nil)
            }
        }

        // Step 5c: text
        //
        if gui.g.text_enabled {
            sdl2.UpdateTexture(gui.texture_txt, nil, gui.g.TFB, gui.x_size*4)
            sdl2.RenderCopy(gui.renderer, gui.texture_txt, nil, nil)
        }

        // Step 5d: border
        //
        if gui.g.border_enabled do draw_border(gui.g)

        // Step  6: present to screen
        sdl2.RenderPresent(gui.renderer)

        // Step 7: back to main loop
        return gui.should_close
}
