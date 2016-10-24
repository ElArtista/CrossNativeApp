package com.example.native_activity;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

public class DummyActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        System.loadLibrary("datcore");

        super.onCreate(savedInstanceState);
        Intent intent = new Intent(this, android.app.NativeActivity.class);
        startActivity(intent);
        finish();
    }
}
