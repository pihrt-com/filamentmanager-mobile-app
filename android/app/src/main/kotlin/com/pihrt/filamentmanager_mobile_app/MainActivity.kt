package com.pihrt.filamentmanager.mobile

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CreateRestoreCredentialRequest
import androidx.credentials.CreateRestoreCredentialResponse
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetRestoreCredentialOption
import androidx.credentials.RestoreCredential
import androidx.credentials.exceptions.restorecredential.E2eeUnavailableException
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private lateinit var credentialManager: CredentialManager
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        credentialManager = CredentialManager.create(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler(::handleMethodCall)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestLocalNetworkAccess" -> requestLocalNetworkAccess(result)
            "createRestoreCredential" -> createRestoreCredential(call, result)
            "getRestoreCredential" -> getRestoreCredential(call, result)
            "clearRestoreCredential" -> clearRestoreCredential(result)
            else -> result.notImplemented()
        }
    }

    private fun requestLocalNetworkAccess(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 37 ||
            checkSelfPermission(Manifest.permission.ACCESS_LOCAL_NETWORK) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.error("permission_in_progress", "A permission request is already active.", null)
            return
        }
        permissionResult = result
        requestPermissions(arrayOf(Manifest.permission.ACCESS_LOCAL_NETWORK), LOCAL_NETWORK_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != LOCAL_NETWORK_REQUEST) return
        val pending = permissionResult
        permissionResult = null
        pending?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
    }

    private fun createRestoreCredential(call: MethodCall, result: MethodChannel.Result) {
        val requestJson = call.argument<String>("requestJson")
        if (requestJson.isNullOrBlank()) {
            result.error("invalid_request", "Restore credential request JSON is missing.", null)
            return
        }
        lifecycleScope.launch {
            try {
                val response = try {
                    credentialManager.createCredential(
                        this@MainActivity,
                        CreateRestoreCredentialRequest(requestJson, isCloudBackupEnabled = true),
                    )
                } catch (_: E2eeUnavailableException) {
                    credentialManager.createCredential(
                        this@MainActivity,
                        CreateRestoreCredentialRequest(requestJson, isCloudBackupEnabled = false),
                    )
                }
                val restoreResponse = response as? CreateRestoreCredentialResponse
                    ?: error("Credential provider returned an unexpected response type.")
                result.success(restoreResponse.responseJson)
            } catch (error: Exception) {
                result.error("restore_create_failed", error.javaClass.simpleName, null)
            }
        }
    }

    private fun getRestoreCredential(call: MethodCall, result: MethodChannel.Result) {
        val requestJson = call.argument<String>("requestJson")
        if (requestJson.isNullOrBlank()) {
            result.error("invalid_request", "Restore credential request JSON is missing.", null)
            return
        }
        lifecycleScope.launch {
            try {
                val response = credentialManager.getCredential(
                    this@MainActivity,
                    GetCredentialRequest(listOf(GetRestoreCredentialOption(requestJson))),
                )
                val credential = response.credential as? RestoreCredential
                    ?: error("Credential provider returned an unexpected credential type.")
                result.success(credential.authenticationResponseJson)
            } catch (error: Exception) {
                result.error("restore_get_failed", error.javaClass.simpleName, null)
            }
        }
    }

    private fun clearRestoreCredential(result: MethodChannel.Result) {
        lifecycleScope.launch {
            try {
                credentialManager.clearCredentialState(
                    ClearCredentialStateRequest(
                        ClearCredentialStateRequest.TYPE_CLEAR_RESTORE_CREDENTIAL,
                    ),
                )
                result.success(null)
            } catch (error: Exception) {
                result.error("restore_clear_failed", error.javaClass.simpleName, null)
            }
        }
    }

    companion object {
        private const val CHANNEL = "com.pihrt.filamentmanager.mobile/android"
        private const val LOCAL_NETWORK_REQUEST = 3701
    }
}
