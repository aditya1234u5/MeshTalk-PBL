package com.meshtalk.android.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Search bar shown above the chat box. While it is open and has text, the chat on screen only
 * shows messages whose text or sender name contains the search text (ignoring upper/lower case).
 */
@Composable
fun ChatSearchBar(
    query: String,
    onQueryChange: (String) -> Unit,
    matchCount: Int,
    colorScheme: ColorScheme,
    onClose: () -> Unit,
    modifier: Modifier = Modifier
) {
    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        try {
            focusRequester.requestFocus()
        } catch (_: Exception) {
            // Focus can fail if the field is not on screen yet; the user can tap it instead
        }
    }
    val muted = colorScheme.onSurfaceVariant

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Search,
                contentDescription = null,
                tint = muted,
                modifier = Modifier.size(18.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            BasicTextField(
                value = query,
                onValueChange = onQueryChange,
                singleLine = true,
                textStyle = TextStyle(color = colorScheme.onSurface, fontSize = 14.sp),
                cursorBrush = SolidColor(colorScheme.primary),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                modifier = Modifier
                    .weight(1f)
                    .focusRequester(focusRequester),
                decorationBox = { innerTextField ->
                    Box {
                        if (query.isEmpty()) {
                            Text(text = "Search messages", color = muted, fontSize = 14.sp)
                        }
                        innerTextField()
                    }
                }
            )
            IconButton(onClick = onClose, modifier = Modifier.size(32.dp)) {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "Close search",
                    tint = muted,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
        Text(
            text = when {
                query.isBlank() -> "Type to filter this chat"
                matchCount == 0 -> "No matches"
                matchCount == 1 -> "1 match"
                else -> "$matchCount matches"
            },
            fontSize = 11.sp,
            color = muted
        )
    }
}

/**
 * Slim row with a search icon, shown above the chat box in chats that have no other status strip
 * (for example private chats). Tapping it should open [ChatSearchBar].
 */
@Composable
fun ChatSearchLauncher(
    onClick: () -> Unit,
    colorScheme: ColorScheme,
    modifier: Modifier = Modifier
) {
    val muted = colorScheme.onSurfaceVariant
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "Search this chat",
            fontSize = 11.sp,
            color = muted,
            modifier = Modifier.weight(1f)
        )
        IconButton(onClick = onClick, modifier = Modifier.size(28.dp)) {
            Icon(
                imageVector = Icons.Default.Search,
                contentDescription = "Search messages",
                tint = muted,
                modifier = Modifier.size(18.dp)
            )
        }
    }
}
