package com.meshtalk.android.ui

import com.meshtalk.android.mesh.MeshService
import com.meshtalk.android.model.BitchatMessage
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Handles processing of IRC-style commands
 */
class CommandProcessor(
    private val state: ChatState,
    private val messageManager: MessageManager,
    private val channelManager: ChannelManager,
    private val privateChatManager: PrivateChatManager,
    private val coroutineScope: CoroutineScope? = null,
    /** Coarse area code attached to SOS alerts; null when the user has location turned off. */
    private val geohashProvider: () -> String? = { null }
) {

    // MeshTalk: state for /sos, /ack, /notice and /notices
    private val noticeBoard = NoticeBoard()
    private var activeSos: SosBroadcaster? = null
    private val seenAckIds = java.util.Collections.synchronizedSet(mutableSetOf<String>())

    // Available commands list
    private val baseCommands = listOf(
        CommandSuggestion("/ack", emptyList(), null, "tell a sender you saw their SOS"),
        CommandSuggestion("/block", emptyList(), "[nickname]", "block or list blocked peers"),
        CommandSuggestion("/channels", emptyList(), null, "show all discovered channels"),
        CommandSuggestion("/clear", emptyList(), null, "clear chat messages"),
        CommandSuggestion("/hug", emptyList(), "<nickname>", "send someone a warm hug"),
        CommandSuggestion("/j", listOf("/join"), "<channel>", "join or create a channel"),
        CommandSuggestion("/m", listOf("/msg"), "<nickname> [message]", "send private message"),
        CommandSuggestion("/nearby", emptyList(), null, "show nearby peers and signal strength"),
        CommandSuggestion("/notice", emptyList(), "<text>", "post an announcement (kept 24h)"),
        CommandSuggestion("/notices", emptyList(), null, "list active announcements"),
        CommandSuggestion("/pay", emptyList(), "<token> [public]", "send a Cashu ecash token"),
        CommandSuggestion("/slap", emptyList(), "<nickname>", "slap someone with a trout"),
        CommandSuggestion("/sos", emptyList(), "[details|cancel]", "broadcast an emergency alert"),
        CommandSuggestion("/unblock", emptyList(), "<nickname>", "unblock a peer"),
        CommandSuggestion("/w", emptyList(), null, "see who's online")
    )
    
    // MARK: - Command Processing
    
    fun processCommand(command: String, meshService: MeshService, myPeerID: String, onSendMessage: (String, List<String>, String?) -> Unit, viewModel: ChatViewModel? = null): Boolean {
        if (!command.startsWith("/")) return false
        
        val parts = command.split(" ")
        val cmd = parts.first().lowercase()
        when (cmd) {
            "/j", "/join" -> handleJoinCommand(parts, myPeerID)
            "/m", "/msg" -> handleMessageCommand(parts, meshService, viewModel)
            "/pay" -> handlePayCommand(command, meshService, myPeerID, onSendMessage, viewModel)
            "/w" -> handleWhoCommand(meshService, viewModel)
            "/clear" -> handleClearCommand()
            "/pass" -> handlePassCommand(parts, myPeerID)
            "/block" -> handleBlockCommand(parts, meshService)
            "/unblock" -> handleUnblockCommand(parts, meshService)
            "/hug" -> handleActionCommand(parts, "gives", "a warm hug ðŸ«‚", meshService, myPeerID, onSendMessage, viewModel)
            "/slap" -> handleActionCommand(parts, "slaps", "around a bit with a large trout ðŸŸ", meshService, myPeerID, onSendMessage, viewModel)
            "/channels" -> handleChannelsCommand()
            "/sos" -> handleSosCommand(command, myPeerID, onSendMessage)
            "/ack" -> handleAckCommand(myPeerID, onSendMessage)
            "/notice" -> handleNoticeCommand(command, myPeerID, onSendMessage)
            "/notices" -> handleNoticesCommand()
            "/nearby" -> handleNearbyCommand(meshService)
            else -> handleUnknownCommand(cmd)
        }
        
        return true
    }
    
    private fun handleJoinCommand(parts: List<String>, myPeerID: String) {
        if (parts.size > 1) {
            val channelName = parts[1]
            val channel = if (channelName.startsWith("#")) channelName else "#$channelName"
            val password = if (parts.size > 2) parts[2] else null
            val success = channelManager.joinChannel(channel, password, myPeerID)
            if (success) {
                val systemMessage = BitchatMessage(
                    sender = "system",
                    content = "joined channel $channel",
                    timestamp = Date(),
                    isRelay = false
                )
                messageManager.addMessage(systemMessage)
            }
        } else {
            val systemMessage = BitchatMessage(
                sender = "system",
                content = "usage: /join <channel>",
                timestamp = Date(),
                isRelay = false
            )
            messageManager.addMessage(systemMessage)
        }
    }
    
    private fun handleMessageCommand(parts: List<String>, meshService: MeshService, viewModel: ChatViewModel?) {
        if (parts.size > 1) {
            val targetName = parts[1].removePrefix("@")
            val peerID = getPeerIDForNickname(targetName, meshService)
            
            if (peerID != null) {
                val success = privateChatManager.startPrivateChat(peerID, meshService)
                
                if (success) {
                    if (parts.size > 2) {
                        val messageContent = parts.drop(2).joinToString(" ")
                        val recipientNickname = getPeerNickname(peerID, meshService)
                        sendPrivateMessage(
                            messageContent, 
                            peerID, 
                            recipientNickname,
                            state.getNicknameValue(),
                            getMyPeerID(meshService),
                            meshService,
                            viewModel
                        )
                    } else {
                        val systemMessage = BitchatMessage(
                            sender = "system",
                            content = "started private chat with $targetName",
                            timestamp = Date(),
                            isRelay = false
                        )
                        messageManager.addMessage(systemMessage)
                    }
                }
            } else {
                val systemMessage = BitchatMessage(
                    sender = "system",
                    content = "user '$targetName' not found. they may be offline or using a different nickname.",
                    timestamp = Date(),
                    isRelay = false
                )
                messageManager.addMessage(systemMessage)
            }
        } else {
            val systemMessage = BitchatMessage(
                sender = "system",
                content = "usage: /msg <nickname> [message]",
                timestamp = Date(),
                isRelay = false
            )
            messageManager.addMessage(systemMessage)
        }
    }
    
    private fun handleWhoCommand(meshService: MeshService, viewModel: ChatViewModel? = null) {
        // Channel-aware who command (matches iOS behavior)
        val (peerList, contextDescription) = if (viewModel != null) {
            when (val selectedChannel = viewModel.selectedLocationChannel.value) {
                is com.meshtalk.android.geohash.ChannelID.Mesh,
                null -> {
                    // Mesh channel: show Bluetooth-connected peers
                    val connectedPeers = state.getConnectedPeersValue()
                    val peerList = connectedPeers.joinToString(", ") { peerID ->
                        getPeerNickname(peerID, meshService)
                    }
                    Pair(peerList, "online users")
                }
                
                is com.meshtalk.android.geohash.ChannelID.Location -> {
                    // Location channel: show geohash participants
                    val geohashPeople = viewModel.geohashPeople.value ?: emptyList()
                    val currentNickname = state.getNicknameValue()
                    
                    val participantList = geohashPeople.mapNotNull { person ->
                        val displayName = person.displayName
                        // Exclude self from list
                        if (displayName.startsWith("${currentNickname}#")) {
                            null
                        } else {
                            displayName
                        }
                    }.joinToString(", ")
                    
                    Pair(participantList, "participants in ${selectedChannel.channel.geohash}")
                }
            }
        } else {
            // Fallback to mesh behavior
            val connectedPeers = state.getConnectedPeersValue()
            val peerList = connectedPeers.joinToString(", ") { peerID ->
                getPeerNickname(peerID, meshService)
            }
            Pair(peerList, "online users")
        }
        
        val systemMessage = BitchatMessage(
            sender = "system",
            content = if (peerList.isEmpty()) {
                "no one else is around right now."
            } else {
                "$contextDescription: $peerList"
            },
            timestamp = Date(),
            isRelay = false
        )
        messageManager.addMessage(systemMessage)
    }
    
    private fun handleClearCommand() {
        when {
            state.getSelectedPrivateChatPeerValue() != null -> {
                // Clear private chat
                val peerID = state.getSelectedPrivateChatPeerValue()!!
                messageManager.clearPrivateMessages(peerID)
                // `/clear` removes history but should not navigate away from the chat the
                // command was issued in. A later message will repopulate this conversation.
                state.setSelectedPrivateChatPeer(peerID)
            }
            state.getCurrentChannelValue() != null -> {
                // Clear channel messages
                val channel = state.getCurrentChannelValue()!!
                messageManager.clearChannelMessages(channel)
            }
            else -> {
                // Clear main messages
                messageManager.clearMessages()
            }
        }
    }

    private fun handlePassCommand(parts: List<String>, peerID: String) {
        val currentChannel = state.getCurrentChannelValue()

        if (currentChannel == null) {
            val systemMessage = BitchatMessage(
                sender = "system",
                content = "you must be in a channel to set a password.",
                timestamp = Date(),
                isRelay = false
            )
            messageManager.addMessage(systemMessage)
            return
        }

        if (parts.size == 2){
            if(!channelManager.isChannelCreator(channel = currentChannel, peerID = peerID)){
                val systemMessage = BitchatMessage(
                    sender = "system",
                    content = "you must be the channel creator to set a password.",
                    timestamp = Date(),
                    isRelay = false
                )
                channelManager.addChannelMessage(currentChannel,systemMessage,null)
                return
            }
            val newPassword = parts[1]
            channelManager.setChannelPassword(currentChannel, newPassword)
            val systemMessage = BitchatMessage(
                sender = "system",
                content = "password changed for channel $currentChannel",
                timestamp = Date(),
                isRelay = false
            )
            channelManager.addChannelMessage(currentChannel,systemMessage,null)
        }
        else{
            val systemMessage = BitchatMessage(
                sender = "system",
                content = "usage: /pass <password>",
                timestamp = Date(),
                isRelay = false
            )
            channelManager.addChannelMessage(currentChannel,systemMessage,null)
        }
    }
    
    private fun handleBlockCommand(parts: List<String>, meshService: MeshService) {
        if (parts.size > 1) {
            val targetName = parts[1].removePrefix("@")
            privateChatManager.blockPeerByNickname(targetName, meshService)
        } else {
            // List blocked users
            val blockedInfo = privateChatManager.listBlockedUsers()
            val systemMessage = BitchatMessage(
                sender = "system",
                content = blockedInfo,
                timestamp = Date(),
                isRelay = false
            )
            messageManager.addMessage(systemMessage)
        }
    }
    
    private fun handleUnblockCommand(parts: List<String>, meshService: MeshService) {
        if (parts.size > 1) {
            val targetName = parts[1].removePrefix("@")
            privateChatManager.unblockPeerByNickname(targetName, meshService)
        } else {
            val systemMessage = BitchatMessage(
                sender = "system",
                content = "usage: /unblock <nickname>",
                timestamp = Date(),
                isRelay = false
            )
            messageManager.addMessage(systemMessage)
        }
    }
    
    private fun handleActionCommand(
        parts: List<String>, 
        verb: String, 
        object_: String, 
        meshService: MeshService,
        myPeerID: String,
        onSendMessage: (String, List<String>, String?) -> Unit,
        viewModel: ChatViewModel?
    ) {
        if (parts.size > 1) {
            val targetName = parts[1].removePrefix("@")
            val actionMessage = "* ${state.getNicknameValue() ?: "someone"} $verb $targetName $object_ *"

            // If we're in a geohash location channel, don't add a local echo here.
            // GeohashViewModel.sendGeohashMessage() will add the local echo with proper metadata.
            val isInLocationChannel = state.selectedLocationChannel.value is com.meshtalk.android.geohash.ChannelID.Location

            // Send as regular message
            if (state.getSelectedPrivateChatPeerValue() != null) {
                val peerID = state.getSelectedPrivateChatPeerValue()!!
                sendPrivateMessage(
                    actionMessage,
                    peerID,
                    getPeerNickname(peerID, meshService),
                    state.getNicknameValue(),
                    myPeerID,
                    meshService,
                    viewModel
                )
            } else if (isInLocationChannel) {
                // Let the transport layer add the echo; just send it out
                onSendMessage(actionMessage, emptyList(), null)
            } else {
                val message = BitchatMessage(
                    sender = state.getNicknameValue() ?: myPeerID,
                    content = actionMessage,
                    timestamp = Date(),
                    isRelay = false,
                    senderPeerID = myPeerID,
                    channel = state.getCurrentChannelValue()
                )
                
                if (state.getCurrentChannelValue() != null) {
                    channelManager.addChannelMessage(state.getCurrentChannelValue()!!, message, myPeerID)
                    onSendMessage(actionMessage, emptyList(), state.getCurrentChannelValue())
                } else {
                    messageManager.addMessage(message)
                    onSendMessage(actionMessage, emptyList(), null)
                }
            }
        } else {
            val systemMessage = BitchatMessage(
                sender = "system",
                content = "usage: /${parts[0].removePrefix("/")} <nickname>",
                timestamp = Date(),
                isRelay = false
            )
            messageManager.addMessage(systemMessage)
        }
    }
    
    // MARK: - MeshTalk commands (SOS, announcements, nearby)

    /** Show our own public message in the main timeline, unless the transport already does. */
    private fun echoLocally(text: String, myPeerID: String) {
        // Geohash channels add their own local echo in the transport layer.
        val isInLocationChannel =
            state.selectedLocationChannel.value is com.meshtalk.android.geohash.ChannelID.Location
        if (isInLocationChannel) return
        messageManager.addMessage(
            BitchatMessage(
                sender = state.getNicknameValue() ?: myPeerID,
                content = text,
                timestamp = Date(),
                isRelay = false,
                senderPeerID = myPeerID
            )
        )
    }

    private fun handleSosCommand(
        command: String,
        myPeerID: String,
        onSendMessage: (String, List<String>, String?) -> Unit
    ) {
        val argument = command.trim().split(Regex("\\s+"), limit = 2).getOrNull(1)?.trim().orEmpty()

        if (argument.equals("cancel", ignoreCase = true) || argument.equals("stop", ignoreCase = true)) {
            val wasRunning = activeSos?.cancel() == true
            addSystemMessage(if (wasRunning) "SOS broadcast stopped." else "no SOS broadcast is running.")
            return
        }
        if (activeSos?.isActive == true) {
            addSystemMessage("an SOS is already being broadcast. use /sos cancel to stop it.")
            return
        }
        val scope = coroutineScope
        if (scope == null) {
            addSystemMessage("SOS is not available right now.")
            return
        }

        // Acknowledgements already in the chat belong to an earlier alert, so they must not stop this one.
        state.getMessagesValue().filter { SosProtocol.isAck(it.content) }.forEach { seenAckIds.add(it.id) }

        val text = SosProtocol.build(argument, geohashProvider())
        echoLocally(text, myPeerID)
        val broadcaster = SosBroadcaster(scope, send = { onSendMessage(text, emptyList(), null) })
        activeSos = broadcaster
        broadcaster.start(text)
        addSystemMessage(
            "SOS sent to everyone in range. it repeats ${SosBroadcaster.DEFAULT_REPEATS} times, " +
                "${SosBroadcaster.DEFAULT_INTERVAL_MS / 1000}s apart, until someone answers with /ack. " +
                "use /sos cancel to stop it."
        )
    }

    private fun handleAckCommand(
        myPeerID: String,
        onSendMessage: (String, List<String>, String?) -> Unit
    ) {
        val text = SosProtocol.buildAck(state.getNicknameValue())
        echoLocally(text, myPeerID)
        onSendMessage(text, emptyList(), null)
    }

    private fun handleNoticeCommand(
        command: String,
        myPeerID: String,
        onSendMessage: (String, List<String>, String?) -> Unit
    ) {
        val body = command.trim().split(Regex("\\s+"), limit = 2).getOrNull(1)?.trim().orEmpty()
        if (body.isEmpty()) {
            addSystemMessage("usage: /notice <announcement> - shared with the mesh and kept for 24 hours")
            return
        }
        val text = NoticeProtocol.build(body)
        echoLocally(text, myPeerID)
        onSendMessage(text, emptyList(), null)
    }

    private fun handleNoticesCommand() {
        val notices = noticeBoard.active()
        if (notices.isEmpty()) {
            addSystemMessage("no active announcements.")
            return
        }
        val timeFormat = java.text.SimpleDateFormat("HH:mm", Locale.getDefault())
        val lines = notices.joinToString("\n") { notice ->
            "[${timeFormat.format(Date(notice.postedAtMs))}] ${notice.sender}: ${notice.text}"
        }
        addSystemMessage("announcements from the last 24 hours:\n$lines")
    }

    private fun handleNearbyCommand(meshService: MeshService) {
        val myPeerID = getMyPeerID(meshService)
        val peers = state.getConnectedPeersValue().filter { it != myPeerID }
        if (peers.isEmpty()) {
            addSystemMessage("no one nearby right now.")
            return
        }
        val rssiByPeer = meshService.getPeerRSSI()
        val lines = peers.joinToString("\n") { peerID ->
            val name = getPeerNickname(peerID, meshService)
            val rssi = rssiByPeer[peerID]
            if (rssi != null) {
                "$name - ${SignalQuality.label(rssi)} signal ($rssi dBm)"
            } else {
                "$name - reached through the mesh"
            }
        }
        addSystemMessage("nearby (${peers.size}):\n$lines")
    }

    /**
     * Feed every public message through here. Collects announcements and stops a running SOS when
     * somebody else acknowledges it. Safe to call again with a message that was already seen.
     */
    fun observePublicMessage(message: BitchatMessage, myPeerID: String) {
        if (message.isPrivate || message.sender == "system") return
        noticeBoard.record(message.id, message.sender, message.content, message.timestamp.time)
        if (SosProtocol.isAck(message.content) &&
            message.senderPeerID != myPeerID &&
            seenAckIds.add(message.id)
        ) {
            if (activeSos?.onAckReceived() == true) {
                addSystemMessage("${message.sender} acknowledged your SOS. broadcast stopped.")
            }
        }
    }

    private fun handleChannelsCommand() {
        val allChannels = channelManager.getJoinedChannelsList()
        val channelList = if (allChannels.isEmpty()) {
            "no channels joined"
        } else {
            "joined channels: ${allChannels.joinToString(", ")}"
        }
        
        val systemMessage = BitchatMessage(
            sender = "system",
            content = channelList,
            timestamp = Date(),
            isRelay = false
        )
        messageManager.addMessage(systemMessage)
    }

    private fun handlePayCommand(
        command: String,
        meshService: MeshService,
        myPeerID: String,
        onSendMessage: (String, List<String>, String?) -> Unit,
        viewModel: ChatViewModel?
    ) {
        val args = command.trim().split(Regex("\\s+")).drop(1)
        if (args.isEmpty()) {
            addSystemMessage("usage: /pay <cashu token> [public] â€” Cashu tokens are bearer instruments")
            return
        }

        val publicConfirmed = args.lastOrNull()?.equals("public", ignoreCase = true) == true
        val rawToken = if (publicConfirmed) args.dropLast(1).joinToString(" ") else args.joinToString(" ")
        val token = CashuTokenDecoder.bareToken(rawToken)
        val info = token?.let { CashuTokenDecoder.decode(it, strict = true) }
        if (token == null || info == null) {
            addSystemMessage("invalid cashu token â€” not sending it")
            return
        }

        val selectedPeer = state.getSelectedPrivateChatPeerValue()
        if (selectedPeer != null) {
            privateChatManager.sendPrivateMessage(
                token,
                selectedPeer,
                getPeerNickname(selectedPeer, meshService),
                state.getNicknameValue(),
                myPeerID
            ) { content, peerID, recipientNickname, messageId ->
                sendPrivateMessageVia(meshService, content, peerID, recipientNickname, messageId, viewModel)
            }
        } else {
            if (!publicConfirmed) {
                addSystemMessage(
                    "Cashu tokens are bearer instruments. Anyone here can redeem this token. " +
                        "Confirm with: /pay <token> public"
                )
                return
            }
            val isLocationChannel =
                state.selectedLocationChannel.value is com.meshtalk.android.geohash.ChannelID.Location
            if (!isLocationChannel) {
                val message = BitchatMessage(
                    sender = state.getNicknameValue() ?: myPeerID,
                    content = token,
                    timestamp = Date(),
                    isRelay = false,
                    senderPeerID = myPeerID,
                    channel = state.getCurrentChannelValue()
                )
                val channel = state.getCurrentChannelValue()
                if (channel != null) channelManager.addChannelMessage(channel, message, myPeerID)
                else messageManager.addMessage(message)
            }
            onSendMessage(token, emptyList(), state.getCurrentChannelValue())
        }

        addSystemMessage(
            "sent ${info.displayAmount ?: "Cashu token"} â€” bearer token; first redeemer wins"
        )
    }

    private fun addSystemMessage(content: String) {
        val message = BitchatMessage(
            sender = "system",
            content = content,
            timestamp = Date(),
            isRelay = false
        )
        val selectedPeer = state.getSelectedPrivateChatPeerValue()
        val selectedLocationChannel = state.selectedLocationChannel.value
        val channel = state.getCurrentChannelValue()
        when {
            selectedPeer != null -> {
                messageManager.addPrivateMessageNoUnread(selectedPeer, message.copy(isPrivate = true))
            }
            selectedLocationChannel is com.meshtalk.android.geohash.ChannelID.Location -> {
                messageManager.addChannelMessage(
                    "geo:${selectedLocationChannel.channel.geohash}",
                    message
                )
            }
            channel != null -> channelManager.addChannelMessage(channel, message, null)
            else -> messageManager.addMessage(message)
        }
    }
    
    private fun handleUnknownCommand(cmd: String) {
        val systemMessage = BitchatMessage(
            sender = "system",
            content = "unknown command: $cmd. type / to see available commands.",
            timestamp = Date(),
            isRelay = false
        )
        messageManager.addMessage(systemMessage)
    }
    
    /**
     * Dismiss the command and mention popups. The composer clears its field in code
     * after a send, which does not run onValueChange, so the popups need an explicit
     * clear.
     */
    fun clearSuggestions() {
        state.setShowCommandSuggestions(false)
        state.setCommandSuggestions(emptyList())
        state.setShowMentionSuggestions(false)
        state.setMentionSuggestions(emptyList())
    }

    // MARK: - Command Autocomplete

    fun updateCommandSuggestions(input: String) {
        if (!input.startsWith("/")) {
            state.setShowCommandSuggestions(false)
            state.setCommandSuggestions(emptyList())
            return
        }
        
        // Get all available commands based on context
        val allCommands = getAllAvailableCommands()
        
        // Filter commands based on input
        val filteredCommands = filterCommands(allCommands, input.lowercase())
        
        if (filteredCommands.isNotEmpty()) {
            state.setCommandSuggestions(filteredCommands)
            state.setShowCommandSuggestions(true)
        } else {
            state.setShowCommandSuggestions(false)
            state.setCommandSuggestions(emptyList())
        }
    }
    
    private fun getAllAvailableCommands(): List<CommandSuggestion> {
        // Add channel-specific commands if in a channel
        val channelCommands = if (state.getCurrentChannelValue() != null) {
            listOf(
                CommandSuggestion("/pass", emptyList(), "[password]", "change channel password"),
                CommandSuggestion("/save", emptyList(), null, "save channel messages locally"),
                CommandSuggestion("/transfer", emptyList(), "<nickname>", "transfer channel ownership")
            )
        } else {
            emptyList()
        }
        
        val isPublicGeohash =
            state.getSelectedPrivateChatPeerValue() == null &&
                state.selectedLocationChannel.value is com.meshtalk.android.geohash.ChannelID.Location
        return (baseCommands + channelCommands).filterNot {
            isPublicGeohash && it.command == "/pay"
        }
    }
    
    private fun filterCommands(commands: List<CommandSuggestion>, input: String): List<CommandSuggestion> {
        return commands.filter { command ->
            // Check primary command
            command.command.startsWith(input) ||
            // Check aliases
            command.aliases.any { it.startsWith(input) }
        }.sortedBy { it.command }
    }
    
    fun selectCommandSuggestion(suggestion: CommandSuggestion): String {
        state.setShowCommandSuggestions(false)
        state.setCommandSuggestions(emptyList())
        return "${suggestion.command} "
    }
    
    // MARK: - Mention Autocomplete
    
    fun updateMentionSuggestions(input: String, meshService: MeshService, viewModel: ChatViewModel? = null) {
        // Check if input contains @ and we're at the end of a word or at the end of input
        val atIndex = input.lastIndexOf('@')
        if (atIndex == -1) {
            state.setShowMentionSuggestions(false)
            state.setMentionSuggestions(emptyList())
            return
        }
        
        // Get the text after the @ symbol
        val textAfterAt = input.substring(atIndex + 1)
        
        // If there's a space after @, don't show suggestions
        if (textAfterAt.contains(' ')) {
            state.setShowMentionSuggestions(false)
            state.setMentionSuggestions(emptyList())
            return
        }
        
        // Get peer candidates based on active channel (matches iOS logic exactly)
        val peerCandidates: List<String> = if (viewModel != null) {
            when (val selectedChannel = viewModel.selectedLocationChannel.value) {
                is com.meshtalk.android.geohash.ChannelID.Mesh,
                null -> {
                    // Mesh channel: use Bluetooth mesh peer nicknames
                    val peerNicknames = meshService.getPeerNicknames()
                    peerNicknames.values.filter { it != peerNicknames[meshService.myPeerID] }
                }
                
                is com.meshtalk.android.geohash.ChannelID.Location -> {
                    // Location channel: use geohash participants with collision-resistant suffixes
                    val geohashPeople = viewModel.geohashPeople.value
                    val currentNickname = state.getNicknameValue()
                    val duplicateNames = duplicateGeohashBaseNames(geohashPeople)
                    
                    geohashPeople.mapNotNull { person ->
                        val baseName = splitSuffix(person.displayName).first
                        val hasNicknameCollision =
                            baseName.lowercase(Locale.ROOT) in duplicateNames
                        val displayName = disambiguatedGeohashDisplayName(person, duplicateNames)
                        // A unique local nickname can be excluded directly. If it collides, the
                        // nickname alone cannot identify which row is self, so keep the suffixed
                        // rows rather than accidentally hiding the other user.
                        if (
                            !hasNicknameCollision &&
                            baseName.equals(currentNickname, ignoreCase = true)
                        ) {
                            null
                        } else {
                            displayName
                        }
                    }
                }
            }
        } else {
            // Fallback to mesh peers if no viewModel available
            val peerNicknames = meshService.getPeerNicknames()
            peerNicknames.values.filter { it != peerNicknames[meshService.myPeerID] }
        }
        
        val filteredNicknames = filterMentionCandidates(peerCandidates, textAfterAt)
        
        if (filteredNicknames.isNotEmpty()) {
            state.setMentionSuggestions(filteredNicknames)
            state.setShowMentionSuggestions(true)
        } else {
            state.setShowMentionSuggestions(false)
            state.setMentionSuggestions(emptyList())
        }
    }
    
    fun selectMentionSuggestion(nickname: String, currentText: String): String {
        state.setShowMentionSuggestions(false)
        state.setMentionSuggestions(emptyList())
        
        // Find the last @ symbol position
        val atIndex = currentText.lastIndexOf('@')
        if (atIndex == -1) {
            return "$currentText@$nickname "
        }
        
        // Replace the text from the @ symbol to the end with the mention
        val textBeforeAt = currentText.substring(0, atIndex)
        return "$textBeforeAt@$nickname "
    }
    
    // MARK: - Utility Functions
    
    private fun getPeerIDForNickname(nickname: String, meshService: MeshService): String? {
        return meshService.getPeerNicknames().entries.find { it.value == nickname }?.key
    }
    
    private fun getPeerNickname(peerID: String, meshService: MeshService): String {
        return meshService.getPeerNicknames()[peerID]
            ?: peerID
    }
    
    private fun getMyPeerID(meshService: MeshService): String {
        return meshService.myPeerID
    }

    private fun sendPrivateMessage(
        content: String,
        peerID: String,
        recipientNickname: String?,
        senderNickname: String?,
        myPeerID: String,
        meshService: MeshService,
        viewModel: ChatViewModel?
    ) {
        val send: (String, String, String, String) -> Unit =
            { messageContent, peerIdParam, recipientNicknameParam, messageId ->
                sendPrivateMessageVia(
                    meshService,
                    messageContent,
                    peerIdParam,
                    recipientNicknameParam,
                    messageId,
                    viewModel
                )
            }
        val scope = coroutineScope
        if (scope == null) {
            privateChatManager.sendPrivateMessage(
                content,
                peerID,
                recipientNickname,
                senderNickname,
                myPeerID,
                send
            )
        } else {
            scope.launch {
                privateChatManager.sendPrivateMessageDurably(
                    content,
                    peerID,
                    recipientNickname,
                    senderNickname,
                    myPeerID,
                    send
                )
            }
        }
    }

    private fun sendPrivateMessageVia(
        meshService: MeshService,
        content: String,
        peerID: String,
        recipientNickname: String,
        messageId: String,
        viewModel: ChatViewModel?
    ) {
        if (viewModel != null) {
            com.meshtalk.android.services.MessageRouter
                .getInstance(viewModel.getApplication(), meshService)
                .sendPrivate(content, peerID, recipientNickname, messageId)
        } else {
            meshService.sendPrivateMessage(content, peerID, recipientNickname, messageId)
        }
    }
}

/**
 * Keep mention autocomplete useful in crowded channels: a bare `anon` identity has not announced
 * a username and is not actionable. Names such as `anon1234` are announced usernames and remain
 * valid mention targets.
 */
internal fun filterMentionCandidates(
    candidates: List<String>,
    query: String
): List<String> {
    return candidates.asSequence()
        .map(String::trim)
        .filter(String::isNotEmpty)
        .filterNot(::isUnannouncedNickname)
        .filter { nickname -> nickname.startsWith(query, ignoreCase = true) }
        .distinctBy { nickname -> nickname.lowercase(Locale.ROOT) }
        .sortedWith(String.CASE_INSENSITIVE_ORDER)
        .toList()
}
