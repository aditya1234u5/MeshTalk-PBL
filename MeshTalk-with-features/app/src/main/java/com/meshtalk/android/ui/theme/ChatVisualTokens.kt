package com.meshtalk.android.ui.theme

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.meshtalk.android.R

/**
 * MeshTalk's UI typeface: the bundled Geist Sans family (clean, proportional, friendly).
 *
 * Keeping the fonts in the APK preserves offline behavior. The original name is kept so every
 * existing call site picks up the new look without edits.
 */
internal val BitchatFontFamily = FontFamily(
    Font(R.font.geist_sans_regular, FontWeight.Normal),
    Font(R.font.geist_sans_medium, FontWeight.Medium),
    Font(R.font.geist_sans_semibold, FontWeight.SemiBold),
    Font(R.font.geist_sans_bold, FontWeight.Bold),
)

/** Monospace companion (Geist Mono) for fingerprints, keys and debug readouts. */
internal val MeshTalkMonoFontFamily = FontFamily(
    Font(R.font.geist_mono_regular, FontWeight.Normal),
    Font(R.font.geist_mono_medium, FontWeight.Medium),
    Font(R.font.geist_mono_semibold, FontWeight.SemiBold),
    Font(R.font.geist_mono_bold, FontWeight.Bold),
)

/** Exact typography, spacing, and opacity values exported for the chat transcript. */
internal object ChatVisualTokens {
    val MessageBodyFontSize: TextUnit = 15.sp
    val MessageBodyLineHeight: TextUnit = 22.sp
    val SenderFontSize: TextUnit = 13.sp
    val SenderLineHeight: TextUnit = 16.sp
    val SystemActionFontSize: TextUnit = 12.sp
    val SystemActionLineHeight: TextUnit = 16.sp
    val SystemTimeFontSize: TextUnit = 10.sp

    val MessageItemSpacing: Dp = 8.dp
    val SenderTopPadding: Dp = 8.dp
    val SenderToBodySpacing: Dp = 4.dp

    // MARK: - Bubble geometry (ChatUiMode.Bubbles)

    /** Rounded corner on the three "free" corners of a message bubble. */
    val BubbleCornerRadius: Dp = 20.dp

    /** Tightened corner on the speaker's own side, giving the bubble a subtle tail. */
    val BubbleTailRadius: Dp = 6.dp

    /** Padding inside a bubble, around the text. */
    val BubblePaddingHorizontal: Dp = 14.dp
    val BubblePaddingVertical: Dp = 10.dp

    /** A bubble never grows past this fraction of the list width, so long lines still wrap. */
    const val BubbleMaxWidthFraction: Float = 0.80f

    /**
     * Author-colour wash inside a bubble. Matches the mention-chip treatment so a tinted
     * bubble stays legible on both the near-black and near-white chat surfaces.
     */
    const val BubbleBackgroundAlpha: Float = 0.18f

    /** Author-colour hairline around a bubble; stronger than the fill so the shape reads. */
    const val BubbleBorderAlpha: Float = 0.38f

    const val SenderSuffixAlpha: Float = 0.60f
    const val HighlightAlpha: Float = 0.20f
    const val MutedTextAlpha: Float = 0.50f

    val MessageBodyStyle = TextStyle(
        fontFamily = BitchatFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = MessageBodyFontSize,
        lineHeight = MessageBodyLineHeight,
    )

    val SenderStyle = TextStyle(
        fontFamily = BitchatFontFamily,
        fontWeight = FontWeight.SemiBold,
        fontSize = SenderFontSize,
        lineHeight = SenderLineHeight,
    )

    val SystemActionStyle = TextStyle(
        fontFamily = BitchatFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = SystemActionFontSize,
        lineHeight = SystemActionLineHeight,
    )
}
