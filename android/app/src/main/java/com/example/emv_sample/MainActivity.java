package com.example.emv_sample;

import android.media.AudioManager;
import android.media.ToneGenerator;
import android.nfc.NfcAdapter;
import android.nfc.Tag;
import android.nfc.tech.IsoDep;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import com.github.devnied.emvnfccard.parser.EmvTemplate;
import com.github.devnied.emvnfccard.parser.IProvider;
import com.google.gson.JsonObject;
import java.io.IOException;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity implements NfcAdapter.ReaderCallback {

    public static final String TAG = "EMVNFCApp";
    private static final String CHANNEL = "com.example.emv_sample";
    NfcAdapter nfcAdapter = null;
    boolean isScanning = false;
    MethodChannel.Result apiResult;
    MethodCall apiCall;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "init": initNFC(result); return;
                case "listen": initListen(result, call); return;
                case "terminate": terminate(result); return;
            }
            result.notImplemented();
        });
    }

    private void terminate(MethodChannel.Result res) {
        if (nfcAdapter != null) {
            nfcAdapter.disableReaderMode(this);
        }
        isScanning = false;
        res.success(true);
    }

    private void initNFC(MethodChannel.Result res) {
        nfcAdapter = NfcAdapter.getDefaultAdapter(this);
        if (nfcAdapter == null) { res.success(0);
            return;
        }
        if (!nfcAdapter.isEnabled()) { res.success(1);
            return;
        }
        res.success(2);
    }

    private void initListen(MethodChannel.Result res, MethodCall call) {
        if (isScanning) { res.success(parsedError("One read operation already running"));
            return;
        }
        if (nfcAdapter == null) { res.success(parsedError("NFC Not Yet Ready"));
            return;
        }
        apiResult = res;
        apiCall = call;
        isScanning = true;
        Bundle options = new Bundle();
        options.putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 250);
        int nfcFlags = NfcAdapter.FLAG_READER_NFC_A | NfcAdapter.FLAG_READER_NFC_B | NfcAdapter.FLAG_READER_NFC_F | NfcAdapter.FLAG_READER_NFC_V | NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS;
        nfcAdapter.enableReaderMode(this, this, nfcFlags, options);
    }

    public void sendCardInfo(String data) {
        JsonObject jsonObject = new JsonObject();
        jsonObject.addProperty("success", true);
        jsonObject.addProperty("cardData", data);
        apiResult.success(jsonObject.toString());
    }

    private String parsedError(String message) {
        JsonObject jsonObject = new JsonObject();
        jsonObject.addProperty("success", false);
        jsonObject.addProperty("error", message);
        return jsonObject.toString();
    }

    @Override
    public void onTagDiscovered(Tag tag) {
        try {
            IsoDep isoDep = IsoDep.get(tag);
            isoDep.connect();
            // Create provider
            IProvider provider = new PcscProvider(isoDep);
            // Define config
            EmvTemplate.Config config = EmvTemplate.Config()
                    .setContactLess(true) // Enable contact less reading (default: true)
                    .setReadAllAids(true) // Read all aids in card (default: true)
                    .setReadTransactions(true) // Read all transactions (default: true)
                    .setReadCplc(false) // Read and extract CPCLC data (default: false)
                    .setRemoveDefaultParsers(false) // Remove default parsers for GeldKarte and EmvCard (default: false)
                    .setReadAt(true) // Read and extract ATR/ATS and description
                    ;
            // Create Parser
            EmvTemplate parser = EmvTemplate.Builder() //
                    .setProvider(provider) // Define provider
                    .setConfig(config) // Define config
                    //.setTerminal(terminal) (optional) you can define a custom terminal implementation to create APDU
                    .build();
            // Card data
            String cardData = String.valueOf(parser.readEmvCard());
            // debug
            Log.i(TAG, cardData);
            // Play sound
            new ToneGenerator(AudioManager.STREAM_MUSIC, 100).startTone(ToneGenerator.TONE_DTMF_P, 500);
            // Read card
            sendCardInfo(cardData);
            isScanning = false; nfcAdapter.disableReaderMode(this); isoDep.close();
        } catch (IOException e) {
            e.printStackTrace();
            // Play sound
            new ToneGenerator(AudioManager.STREAM_MUSIC, 100).startTone(ToneGenerator.TONE_DTMF_P, 500);
            // Send error
            apiResult.success(parsedError("Issue with card read"));
            isScanning = false; nfcAdapter.disableReaderMode(this);
        }
    }

    @Override
    public void onPointerCaptureChanged(boolean hasCapture) {
        super.onPointerCaptureChanged(hasCapture);
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (nfcAdapter != null) {
            nfcAdapter.disableReaderMode(this);
            if (isScanning) { finish(); }
        }
    }
}
