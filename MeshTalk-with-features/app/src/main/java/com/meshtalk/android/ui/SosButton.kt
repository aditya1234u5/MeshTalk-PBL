package com.meshtalk.android.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.meshtalk.android.R

/**
 * Red "SOS" button for the chat header. Tapping it asks for confirmation first so a pocket tap
 * cannot raise a false alarm; confirming runs [onConfirmed] (the header sends the /sos command).
 */
@Composable
fun SosHeaderButton(
    onConfirmed: () -> Unit,
    modifier: Modifier = Modifier
) {
    var showConfirmation by remember { mutableStateOf(false) }
    val alertColor = MaterialTheme.colorScheme.error

    Box(
        modifier = modifier
            .size(40.dp)
            .clip(CircleShape)
            .clickable(
                role = Role.Button,
                onClickLabel = stringResource(R.string.sos_button_label)
            ) { showConfirmation = true },
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = stringResource(R.string.sos_button_label),
            color = alertColor,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold
        )
    }

    if (showConfirmation) {
        AlertDialog(
            onDismissRequest = { showConfirmation = false },
            title = { Text(stringResource(R.string.sos_dialog_title)) },
            text = { Text(stringResource(R.string.sos_dialog_message)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        showConfirmation = false
                        onConfirmed()
                    }
                ) {
                    Text(text = stringResource(R.string.sos_dialog_confirm), color = alertColor)
                }
            },
            dismissButton = {
                TextButton(onClick = { showConfirmation = false }) {
                    Text(stringResource(R.string.sos_dialog_cancel))
                }
            }
        )
    }
}
