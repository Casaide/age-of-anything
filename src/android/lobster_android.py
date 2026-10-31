# Patches a copy of Lobster's engine for the Android build (Lobster's own tree is left alone):
# - ReadTexture on GLES: there's no glGetTexImage, so the texture is attached to a framebuffer and read with
#   glReadPixels (the game reads its bakes back this way).
# - A touch's position from its own event: Lobster looked the finger up in SDL's current list, so a tap whose
#   press and lift were read in the same frame (a slow frame) lost its position and clicked at (0, 0).
# - Buttons as they are this frame on touch too: Lobster gave touch builds the last frame's (so a finger hovered a
#   frame before it pressed), which lost a tap pressed and lifted in one frame; the position now comes with the press.
#   python3 lobster_android.py <copied dev/src>
import sys
p = sys.argv[1] + '/gltexture.cpp'
s = open(p).read()
old = '''        GL_CALL(glGetTexImage(tex.type, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels));
        return pixels;
    #else
        return nullptr;
    #endif'''
new = '''        GL_CALL(glGetTexImage(tex.type, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels));
        return pixels;
    #else
        if (tex.type != GL_TEXTURE_2D) return nullptr;
        GLint was = 0;
        GL_CALL(glGetIntegerv(GL_FRAMEBUFFER_BINDING, &was));
        GLuint fb = 0;
        GL_CALL(glGenFramebuffers(1, &fb));
        GL_CALL(glBindFramebuffer(GL_FRAMEBUFFER, fb));
        GL_CALL(glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex.id, 0));
        auto pixels = new uint8_t[tex.size.x * tex.size.y * 4];
        GL_CALL(glPixelStorei(GL_PACK_ALIGNMENT, 1));
        GL_CALL(glReadPixels(0, 0, tex.size.x, tex.size.y, GL_RGBA, GL_UNSIGNED_BYTE, pixels));
        GL_CALL(glBindFramebuffer(GL_FRAMEBUFFER, (GLuint)was));
        GL_CALL(glDeleteFramebuffers(1, &fb));
        return pixels;
    #endif'''
assert s.count(old) == 1, 'ReadTexture changed upstream: look again'
open(p, 'w').write(s.replace(old, new))

p = sys.argv[1] + '/sdlsystem.cpp'
s = open(p).read()
start = s.index('int updatedragpos(SDL_TouchFingerEvent &e, Uint32 et) {')
end = s.index('\n}\n', start) + 3
s = s[:start] + """int updatedragpos(SDL_TouchFingerEvent &e, Uint32 et) {
    int j = findfinger(e.fingerID, et == SDL_EVENT_FINGER_UP);
    auto &f = fingers[j];
    f.mousepos = double2(e.x, e.y) * double2(screensize) * inputscale;
    f.mousedelta += double2(e.dx, e.dy) * double2(screensize);
    return j;
}
""" + s[end:]
old = """                int i = findfinger(event.tfinger.fingerID, true);
                updatemousebutton(1, i, false);"""
assert s.count(old) == 1
s = s.replace(old, """                int i = updatedragpos(event.tfinger, event.type);
                updatemousebutton(1, i, false);""")
open(p, 'w').write(s)

old = """        return ks.Prev();
    #else
        return ks.State();"""
assert s.count(old) == 1
s = s.replace(old, """        return ks.State();
    #else
        return ks.State();""")
open(p, 'w').write(s)
