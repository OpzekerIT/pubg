# -*- coding: utf-8 -*-
"""
Discord bot for team creation, stats reporting, and event logging.
"""

import json
import os
import discord
import random
import asyncio
import re
import logging
from discord.ext import commands

# --- Configuration ---

# TODO: Move hardcoded channel names to a config file or environment variables
TEAMIFY_VOICE_CHANNEL = "teamify"
TEAMIFY_TEXT_CHANNEL = "teamify"
TEMP_CATEGORY_NAME = "Temporary Teams"
LOGGING_CHANNEL = "logging"
WELCOME_CHANNEL = "raadhuisplein"
GOD_CHANNEL = "GOD_CHANNEL" # Channel to ignore for voice logging

# TODO: Move stats file path to config
STATS_FILE_PATH = os.path.join("..", "data", "player_last_stats.json")
CONFIG_PHP_PATH = "config.php" # Path relative to this script's location

# --- Logging Setup ---
# Basic logging to console
logging.basicConfig(level=logging.INFO, format='%(asctime)s:%(levelname)s:%(name)s: %(message)s')
logger = logging.getLogger('discord_bot')

# --- Helper Functions ---

def get_token_from_php(config_path):
    """
    Reads the bot token from a PHP config file.

    WARNING: This method of storing secrets is insecure.
             Consider using environment variables or a dedicated secrets management solution.
    """
    try:
        with open(config_path, "r", encoding="utf-8") as file:
            content = file.read()
            # Regex to find $bottoken = 'TOKEN_VALUE';
            match = re.search(r"\$bottoken\s*=\s*'(.+?)'", content)
            if match:
                logger.info("Successfully extracted bot token from %s", config_path)
                return match.group(1)
            else:
                logger.error("Bot token pattern not found in %s", config_path)
                return None
    except FileNotFoundError:
        logger.error("Config file not found at %s", config_path)
        return None
    except Exception as e:
        logger.exception("Error reading or parsing config file %s: %s", config_path, e)
        return None

async def cleanup_empty_channels(guild, temp_channels, ctx_channel):
    """
    Periodically checks and removes empty temporary voice channels.
    """
    while temp_channels:
        await asyncio.sleep(60)  # Check every 60 seconds
        for channel in temp_channels[:]: # Iterate over a copy
            try:
                # Refresh channel state
                current_channel = guild.get_channel(channel.id)
                if current_channel and isinstance(current_channel, discord.VoiceChannel):
                    if len(current_channel.members) == 0:
                        logger.info("Deleting empty temporary channel: %s", current_channel.name)
                        await current_channel.delete(reason="Channel empty")
                        temp_channels.remove(channel)
                        # Optionally notify in the original context channel
                        # await ctx_channel.send(f"Kanaal {channel.name} is opgeruimd omdat het leeg was!")
                elif current_channel is None:
                     # Channel might have been deleted manually
                     logger.warning("Temporary channel %s (ID: %d) not found, removing from tracking list.", channel.name, channel.id)
                     temp_channels.remove(channel)

            except discord.Forbidden:
                logger.error("Missing permissions to delete channel %s", channel.name)
                # Remove from list to avoid repeated attempts if permissions are missing
                temp_channels.remove(channel)
            except discord.NotFound:
                 logger.warning("Attempted to delete channel %s but it was already gone.", channel.name)
                 if channel in temp_channels:
                     temp_channels.remove(channel)
            except Exception as e:
                logger.exception("Error during temporary channel cleanup for %s: %s", channel.name, e)
                # Remove from list to avoid potential infinite loops on persistent errors
                if channel in temp_channels:
                    temp_channels.remove(channel)

# --- Bot Setup ---

token = get_token_from_php(CONFIG_PHP_PATH)
if not token:
    logger.critical("Bot token not found or could not be read. Exiting.")
    exit() # Exit if token is essential

# Define Intents
intents = discord.Intents.default()
intents.voice_states = True
intents.guilds = True
intents.messages = True
intents.message_content = True
intents.presences = True # Required if the bot needs to see presences
intents.members = True   # Required to see members in voice channels and for join/remove events

bot = commands.Bot(command_prefix="!", intents=intents)

# --- Events ---

@bot.event
async def on_ready():
    """Called when the bot is ready and connected."""
    logger.info('Bot is ingelogd als %s (ID: %s)', bot.user, bot.user.id)
    print(f'Bot is ingelogd als {bot.user}') # Keep console output for convenience

@bot.event
async def on_command_error(ctx, error):
    """Global command error handler."""
    if isinstance(error, commands.CommandNotFound):
        # Optionally ignore 'Command not found' errors or send a message
        # await ctx.send("Onbekend commando.")
        logger.warning("Command not found: %s", ctx.message.content)
    elif isinstance(error, commands.MissingRequiredArgument):
        await ctx.send(f"Je mist een argument: {error.param.name}")
    elif isinstance(error, commands.BadArgument):
        await ctx.send("Ongeldig argument opgegeven.")
    elif isinstance(error, commands.CheckFailure):
        await ctx.send("Je hebt geen permissies voor dit commando of kanaal.")
    else:
        # Log other errors
        logger.exception("Unhandled command error in '%s': %s", ctx.command, error)
        try:
            # Attempt to notify user about unexpected error
            await ctx.send("Er is een onverwachte fout opgetreden.")
        except discord.HTTPException:
            pass # Ignore if we can't send the error message

@bot.event
async def on_voice_state_update(member, before, after):
    """Logs user movements between voice channels."""
    # Ignore bots
    if member.bot:
        return

    logging_channel = discord.utils.get(member.guild.text_channels, name=LOGGING_CHANNEL)
    if not logging_channel:
        logger.warning("Logging channel '%s' not found.", LOGGING_CHANNEL)
        return

    # Ignore movements involving the GOD_CHANNEL
    if (before.channel and before.channel.name == GOD_CHANNEL) or \
       (after.channel and after.channel.name == GOD_CHANNEL):
        return

    try:
        if before.channel is None and after.channel is not None:
            # Member joins a voice channel
            logger.info("%s joined voice channel: %s", member.display_name, after.channel.name)
            await logging_channel.send(f"🔊 {member.mention} is gejoined in voice kanaal: **{after.channel.name}**")
        elif before.channel is not None and after.channel is None:
            # Member leaves a voice channel
            logger.info("%s left voice channel: %s", member.display_name, before.channel.name)
            await logging_channel.send(f"🔇 {member.mention} heeft het voice kanaal **{before.channel.name}** verlaten.")
        elif before.channel != after.channel:
            # Member switches voice channels
            logger.info("%s switched from %s to %s", member.display_name, before.channel.name, after.channel.name)
            await logging_channel.send(f"🔄 {member.mention} is van **{before.channel.name}** naar **{after.channel.name}** gegaan.")
    except discord.Forbidden:
         logger.error("Missing permissions to send message in logging channel '%s'", LOGGING_CHANNEL)
    except Exception as e:
        logger.exception("Error during on_voice_state_update: %s", e)

@bot.event
async def on_member_join(member):
    """Welcomes new members."""
    if member.bot: return # Ignore bots

    welcome_channel = discord.utils.get(member.guild.text_channels, name=WELCOME_CHANNEL)
    if welcome_channel:
        logger.info("Member joined: %s", member.display_name)
        try:
            await welcome_channel.send(f"🎉 Welkom {member.mention} op de server! We hopen dat je een leuke tijd hebt!")
        except discord.Forbidden:
            logger.error("Missing permissions to send message in welcome channel '%s'", WELCOME_CHANNEL)
        except Exception as e:
             logger.exception("Error during on_member_join: %s", e)
    else:
        logger.warning("Welcome channel '%s' not found.", WELCOME_CHANNEL)

@bot.event
async def on_member_remove(member):
    """Logs when members leave."""
    if member.bot: return # Ignore bots

    goodbye_channel = discord.utils.get(member.guild.text_channels, name=WELCOME_CHANNEL) # Using same channel as welcome
    if goodbye_channel:
        logger.info("Member left: %s", member.display_name)
        try:
            await goodbye_channel.send(f"😢 {member.display_name} heeft de server verlaten. We zullen je missen!") # Use display_name as mention won't work
        except discord.Forbidden:
            logger.error("Missing permissions to send message in goodbye channel '%s'", WELCOME_CHANNEL)
        except Exception as e:
             logger.exception("Error during on_member_remove: %s", e)
    else:
        logger.warning("Goodbye channel '%s' not found.", WELCOME_CHANNEL)


# --- Commands ---

@bot.command()
async def test(ctx):
    """A simple test command."""
    await ctx.send("Test geslaagd!")

@bot.command()
async def teamify(ctx, *args):
    """
    Splits members in the 'teamify' voice channel into random teams.

    Usage:
    !teamify - Auto-split into teams of 4.
    !teamify <num_teams> - Split into a specific number of teams.
    !teamify move - Auto-split and move to temporary channels.
    !teamify <num_teams> move - Split into specific teams and move.
    !teamify help - Show help message.
    """
    # Handle help argument first
    if "help" in [arg.lower() for arg in args]:
        help_message = (
            "**Gebruik van !teamify:**\n"
            f"`!teamify` - Verdeel spelers in `{TEAMIFY_VOICE_CHANNEL}` in teams van max. 4.\n"
            "`!teamify <aantal_teams>` - Verdeel spelers in een opgegeven aantal teams.\n"
            "`!teamify move` - Verdeel spelers automatisch en verplaats ze naar tijdelijke kanalen.\n"
            "`!teamify <aantal_teams> move` - Verdeel spelers en verplaats ze.\n"
            "`!teamify help` - Toon dit bericht."
        )
        await ctx.send(help_message)
        return

    # Check if command is used in the correct text channel
    if ctx.channel.name != TEAMIFY_TEXT_CHANNEL:
        await ctx.send(f"Dit commando kan alleen worden gebruikt in het #{TEAMIFY_TEXT_CHANNEL} kanaal.")
        return

    guild = ctx.guild
    source_voice_channel = discord.utils.get(guild.voice_channels, name=TEAMIFY_VOICE_CHANNEL)

    if not source_voice_channel:
        await ctx.send(f"Voice kanaal '{TEAMIFY_VOICE_CHANNEL}' niet gevonden!")
        return

    if not source_voice_channel.members:
        await ctx.send(f"Er zijn geen mensen in het kanaal '{TEAMIFY_VOICE_CHANNEL}' om teams van te maken!")
        return

    members = list(source_voice_channel.members) # Get a mutable list
    random.shuffle(members)
    member_count = len(members)

    # Parse arguments
    num_teams_arg = 0
    move_players = False
    for arg in args:
        if arg.isdigit():
            num_teams_arg = int(arg)
        elif arg.lower() == "move":
            move_players = True

    # Determine number of teams
    if num_teams_arg <= 0:
        # Auto-calculate based on team size 4, minimum 1 team
        num_teams = (member_count + 3) // 4 if member_count > 0 else 1
    else:
        num_teams = num_teams_arg

    # Ensure num_teams is valid
    num_teams = max(1, min(num_teams, member_count)) # At least 1 team, max members count

    # Create teams
    teams = [[] for _ in range(num_teams)]
    for i, member in enumerate(members):
        teams[i % num_teams].append(member)

    # Find the output text channel
    output_text_channel = discord.utils.get(guild.text_channels, name=TEAMIFY_TEXT_CHANNEL)
    if not output_text_channel:
        # Fallback to context channel if specific channel not found
        logger.warning("Output text channel '%s' not found, using context channel.", TEAMIFY_TEXT_CHANNEL)
        output_text_channel = ctx.channel
        # await ctx.send(f"Tekst kanaal '{TEAMIFY_TEXT_CHANNEL}' bestaat niet! Resultaten worden hier gepost.")

    # Prepare message and temporary channels if moving
    message = f"Willekeurige teams uit {source_voice_channel.mention}:\n\n"
    temp_channels = []
    category = None

    if move_players:
        try:
            category = discord.utils.get(guild.categories, name=TEMP_CATEGORY_NAME)
            if not category:
                logger.info("Creating category '%s'", TEMP_CATEGORY_NAME)
                category = await guild.create_category(TEMP_CATEGORY_NAME, reason="Teamify temporary channels")
        except discord.Forbidden:
            await ctx.send(f"Ik heb geen permissies om de categorie '{TEMP_CATEGORY_NAME}' te maken.")
            move_players = False # Disable moving if category creation fails
            logger.error("Missing permissions to create category '%s'", TEMP_CATEGORY_NAME)
        except Exception as e:
             await ctx.send("Fout bij het maken/vinden van de categorie.")
             move_players = False
             logger.exception("Error finding/creating category '%s': %s", TEMP_CATEGORY_NAME, e)

    # Build message and move players
    move_tasks = []
    for i, team in enumerate(teams, start=1):
        team_names = ', '.join([member.mention for member in team])
        message += f"**Team {i}:** {team_names}\n"

        if move_players and category:
            try:
                channel_name = f"Squad {i}"
                logger.info("Creating temporary voice channel: %s", channel_name)
                temp_channel = await guild.create_voice_channel(channel_name, category=category, reason="Teamify command")
                temp_channels.append(temp_channel)
                for member in team:
                    # Add move operation to a list to run concurrently
                    move_tasks.append(member.move_to(temp_channel))
            except discord.Forbidden:
                 await ctx.send(f"Ik heb geen permissies om voice kanaal 'Squad {i}' te maken of leden te verplaatsen.")
                 logger.error("Missing permissions to create/move for Squad %d", i)
                 # Optionally stop creating more channels if one fails
            except Exception as e:
                await ctx.send(f"Fout bij het maken van kanaal 'Squad {i}'.")
                logger.exception("Error creating channel 'Squad %d': %s", i, e)

    # Send the team message
    try:
        await output_text_channel.send(message)
        logger.info("Posted team message to #%s", output_text_channel.name)
    except discord.Forbidden:
         await ctx.send(f"Ik heb geen permissies om berichten te sturen in #{output_text_channel.name}.")
         logger.error("Missing permissions to send message in #%s", output_text_channel.name)
    except Exception as e:
        await ctx.send("Fout bij het versturen van het team bericht.")
        logger.exception("Error sending team message: %s", e)

    # Execute moves concurrently
    if move_tasks:
        logger.info("Moving %d members to temporary channels...", len(move_tasks))
        results = await asyncio.gather(*move_tasks, return_exceptions=True)
        moved_count = 0
        for i, result in enumerate(results):
            member_to_move = move_tasks[i].__self__ # Get the member object from the coroutine
            if isinstance(result, Exception):
                logger.error("Failed to move member %s: %s", member_to_move.display_name, result)
                try:
                    # Try to notify in context channel about failed move
                    await ctx.send(f"Kon {member_to_move.mention} niet verplaatsen: {result}")
                except discord.HTTPException: pass # Ignore if sending fails
            else:
                moved_count += 1
        logger.info("Finished moving members. Successful moves: %d", moved_count)
        await ctx.send(f"Teams zijn gepost in #{output_text_channel.name}! {moved_count} speler(s) verplaatst.")
    elif move_players: # If move was intended but failed (e.g., category issue)
         await ctx.send(f"Teams zijn gepost in #{output_text_channel.name}. Kon spelers niet verplaatsen.")
    else:
         await ctx.send(f"Teams zijn gepost in #{output_text_channel.name}.")


    # Start background task for cleaning up empty channels if channels were created
    if temp_channels:
        logger.info("Starting background task to clean up %d temporary channels.", len(temp_channels))
        bot.loop.create_task(cleanup_empty_channels(guild, temp_channels, ctx.channel))


@bot.command()
async def whoisbest(ctx, category="Casual", matchesback: int = 18):
    """
    Shows top 3 players by winrate and AHD for a given category.

    Usage: !whoisbest [category] [min_matches]
    Example: !whoisbest Ranked 10
    """
    if category.lower() == "help":
        help_message = (
            "**Gebruik van `!whoisbest`:**\n"
            "`!whoisbest [category] [min_matches]`\n\n"
            "**Parameters:**\n"
            "`category` - Stats categorie (bijv. 'Casual', 'Ranked', 'Intense'). Niet hoofdlettergevoelig. Standaard: 'Casual'.\n"
            "`min_matches` - Minimum aantal matches gespeeld. Standaard: 18.\n\n"
            "**Voorbeeld:** `!whoisbest Ranked 10`\n"
            "Toont top 3 Win% en AHD voor Ranked met minimaal 10 matches.\n"
        )
        await ctx.send(help_message)
        return

    logger.info("Whoisbest command invoked: category=%s, matchesback=%d", category, matchesback)

    try:
        # Read JSON file
        if not os.path.exists(STATS_FILE_PATH):
             await ctx.send(f"Statistieken bestand niet gevonden ({STATS_FILE_PATH}).")
             logger.error("Stats file not found: %s", STATS_FILE_PATH)
             return

        with open(STATS_FILE_PATH, "r", encoding="utf-8") as file:
            data = json.load(file)

        # Create case-insensitive mapping for categories
        category_mapping = {cat.lower(): cat for cat in data.keys() if isinstance(data[cat], list)} # Only map list categories

        lower_category = category.lower()

        if lower_category not in category_mapping:
            available_categories = ', '.join(category_mapping.values()) # Show original names
            await ctx.send(f"Ongeldige categorie '{category}'. Beschikbaar: {available_categories}")
            logger.warning("Invalid category requested: %s", category)
            return

        actual_category = category_mapping[lower_category]
        logger.info("Processing category: %s", actual_category)

        # Filter players based on minimum matches
        players_in_category = data.get(actual_category, [])
        if not isinstance(players_in_category, list):
             await ctx.send(f"Data voor categorie '{actual_category}' is niet in het verwachte formaat.")
             logger.error("Invalid data format for category '%s'", actual_category)
             return

        filtered_players = [
            player for player in players_in_category
            if isinstance(player, dict) and player.get("matches", 0) >= matchesback
        ]
        logger.info("Found %d players meeting criteria (>=%d matches) in %s", len(filtered_players), matchesback, actual_category)

        if not filtered_players:
            await ctx.send(f"Geen spelers gevonden voor '{actual_category}' met ≥ {matchesback} matches.")
            return

        # Safely sort players, handling potential missing keys or non-numeric data
        def safe_get_float(player_dict, key, default=0.0):
            val = player_dict.get(key)
            if isinstance(val, (int, float)):
                return float(val)
            # Try converting comma decimal separator if needed
            if isinstance(val, str):
                try: return float(val.replace(',', '.'))
                except ValueError: return default
            return default

        top_winratio = sorted(filtered_players, key=lambda x: safe_get_float(x, "winratio"), reverse=True)[:3]
        top_ahd = sorted(filtered_players, key=lambda x: safe_get_float(x, "ahd"), reverse=True)[:3]

        # Build the response message
        response_message = f"**📊 Top Stats voor '{actual_category}' (min {matchesback} matches)**\n\n"

        response_message += "**\U0001F3C6 Top 3 Winratio**\n"
        if top_winratio:
            for i, player in enumerate(top_winratio, start=1):
                player_name = player.get('playername', 'Onbekend')
                win_ratio = safe_get_float(player, 'winratio')
                response_message += f"{i}. **{player_name}** - {win_ratio:.2f}%\n"
        else:
            response_message += "_Geen data beschikbaar_\n"

        response_message += f"\n**\U0001F4A5 Top 3 Average Human Damage (AHD)**\n" # Changed emoji
        if top_ahd:
            for i, player in enumerate(top_ahd, start=1):
                player_name = player.get('playername', 'Onbekend')
                ahd_val = safe_get_float(player, 'ahd')
                response_message += f"{i}. **{player_name}** - {ahd_val:.2f}\n"
        else:
             response_message += "_Geen data beschikbaar_\n"

        await ctx.send(response_message)
        logger.info("Successfully sent whoisbest stats for %s", actual_category)

    except FileNotFoundError:
        await ctx.send(f"Statistieken bestand niet gevonden ({STATS_FILE_PATH}).")
        logger.error("Stats file not found: %s", STATS_FILE_PATH)
    except json.JSONDecodeError:
        await ctx.send("Fout bij het lezen van de statistieken (ongeldig JSON).")
        logger.exception("JSONDecodeError reading stats file: %s", STATS_FILE_PATH)
    except Exception as e:
        await ctx.send(f"Onverwachte fout bij het ophalen van statistieken: {e}")
        logger.exception("Error in whoisbest command: %s", e)


@bot.command()
@commands.has_permissions(move_members=True) # Add permission check
async def moveall(ctx):
    """Moves all members from other voice channels to the 'teamify' channel."""
    # Check if command is used in the correct text channel
    if ctx.channel.name != TEAMIFY_TEXT_CHANNEL:
        await ctx.send(f"Dit commando kan alleen worden gebruikt in het #{TEAMIFY_TEXT_CHANNEL} tekstkanaal.")
        return

    guild = ctx.guild
    target_channel = discord.utils.get(guild.voice_channels, name=TEAMIFY_VOICE_CHANNEL)

    if not target_channel:
        await ctx.send(f"Het '{TEAMIFY_VOICE_CHANNEL}' voice-kanaal bestaat niet!")
        logger.error("Target voice channel '%s' not found for moveall.", TEAMIFY_VOICE_CHANNEL)
        return

    moved_members_count = 0
    move_tasks = []
    members_to_move = []

    logger.info("Moveall command initiated by %s", ctx.author.display_name)
    for channel in guild.voice_channels:
        # Skip the target channel itself and channels with no members
        if channel == target_channel or not channel.members:
            continue

        for member in channel.members:
             # Avoid moving bots unless intended
             # if member.bot: continue
             members_to_move.append(member)
             move_tasks.append(member.move_to(target_channel))

    if not move_tasks:
        await ctx.send("Er waren geen spelers in andere kanalen om te verplaatsen.")
        logger.info("Moveall: No members found in other channels.")
        return

    logger.info("Attempting to move %d members to #%s", len(move_tasks), target_channel.name)
    results = await asyncio.gather(*move_tasks, return_exceptions=True)

    for i, result in enumerate(results):
        member = members_to_move[i]
        if isinstance(result, Exception):
            logger.error("Failed to move member %s: %s", member.display_name, result)
            try:
                await ctx.send(f"Kon {member.mention} niet verplaatsen: {result}")
            except discord.HTTPException: pass
        else:
            moved_members_count += 1

    logger.info("Moveall finished. Successfully moved %d members.", moved_members_count)
    if moved_members_count > 0:
        await ctx.send(f"{moved_members_count} speler(s) zijn verplaatst naar het {target_channel.mention} kanaal.")
    else:
         await ctx.send("Kon geen spelers verplaatsen (controleer permissies?).")


@moveall.error
async def moveall_error(ctx, error):
    """Error handler specific to moveall command."""
    if isinstance(error, commands.MissingPermissions):
        await ctx.send("Je hebt geen permissies om leden te verplaatsen.")
    else:
        # Log and notify for other errors related to moveall
        logger.exception("Error in moveall command: %s", error)
        await ctx.send("Er is een fout opgetreden bij het uitvoeren van `moveall`.")


# --- Run Bot ---
if __name__ == "__main__":
    logger.info("Starting bot...")
    bot.run(token)
