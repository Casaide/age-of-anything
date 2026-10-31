package com.ageofanything.game;

import android.os.Bundle;
import android.view.View;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import org.libsdl.app.SDLActivity;

// The game's activity: the folders it writes into made first (Lobster has no mkdir, and the desktop scripts make
// them), the bake cache emptied when the bake version changes (as bake_cache.sh does), then the lobby.
public class Game extends SDLActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        File dir = getExternalFilesDir(null);
        for (String sub : new String[] { "bake_cache", "saves", "races" }) new File(dir, sub).mkdirs();
        try {
            File mark = new File(dir, "bake_cache/version");
            String version;
            try (InputStream in = getAssets().open("bake_version")) {
                version = new String(in.readAllBytes(), StandardCharsets.UTF_8).trim();
            }
            String had = mark.exists() ? new String(Files.readAllBytes(mark.toPath()), StandardCharsets.UTF_8).trim() : "";
            if (!had.equals(version)) {
                File[] old = new File(dir, "bake_cache").listFiles();
                if (old != null) for (File f : old) f.delete();
                try (FileOutputStream out = new FileOutputStream(mark)) { out.write(version.getBytes(StandardCharsets.UTF_8)); }
            }
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
        super.onCreate(savedInstanceState);
    }

    // Fullscreen: the status and navigation bars hidden (they covered the top bar), back on a swipe from the edge.
    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            | View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
    }

    @Override
    protected String[] getLibraries() {
        return new String[] { "main" };   // (SDL is built into the game's library)
    }

    @Override
    protected String[] getArguments() {
        return new String[] { "none", "lobby", "touch" };
    }
}
