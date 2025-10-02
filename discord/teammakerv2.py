import json
import os
import discord
import random
import asyncio
import re
from discord.ext import commands


def get_token():
    with open("config.php", "r") as file:
        content = file.read()
        match = re.search(r"bottoken\s*=\s*'(.+?)'", content)
        if match:
            return match.group(1)
    return None

token = get_token()
if not token:
    raise ValueError("Bot token niet gevonden in config.php")

# Intents instellen
intents = discord.Intents.default()
intents.voice_states = True
intents.guilds = True
intents.messages = True
intents.message_content = True
intents.presences = True  # Nodig als de bot presences moet zien
intents.members = True  # Nodig om leden in een voice channel te zien

bot = commands.Bot(command_prefix="!", intents=intents)

@bot.event
async def on_ready():
    print(f'Bot is ingelogd als {bot.user}')
    channel = bot.get_channel(759006368832159745)
    if channel:
        await channel.send("Ben er weer!")

@bot.command()
async def test(ctx):
    await ctx.send("Test geslaagd!")

@bot.command()
async def teamify(ctx, *args):
    for arg in args:
        if arg.lower() == "help":
            help_message = (
                "**Gebruik van !teamify:**\n"
                "`!teamify` - Verdeel spelers in teams van max. 4 personen.\n"
                "`!teamify <aantal_teams>` - Verdeel spelers in een opgegeven aantal teams.\n"
                "`!teamify <aantal_teams> move` - Verdeel spelers en verplaats ze naar tijdelijke voice-kanalen.\n"
                "`!teamify move` - Verdeel spelers automatisch en verplaats ze naar tijdelijke voice-kanalen."
            )
            await ctx.send(help_message)
            return

    # Beperk het commando tot alleen het kanaal "teamify"
    if ctx.channel.name != "teamify":
        await ctx.send("Dit commando kan alleen worden gebruikt in het #teamify kanaal.")
        return

    guild = ctx.guild
    voice_channel = discord.utils.get(guild.voice_channels, name="teamify")

    if not voice_channel or len(voice_channel.members) == 0:
        await ctx.send("Er zijn geen mensen in het kanaal 'teamify' om teams van te maken!")
        return

    members = voice_channel.members
    random.shuffle(members)

    # Standaardwaarden
    num_teams = 0
    move_players = False

    # Verwerk argumenten
    for arg in args:
        if arg.isdigit():  # Als het een getal is, gebruik het als het aantal teams
            num_teams = int(arg)
        elif arg.lower() == "move":  # Als 'true' is opgegeven, verplaats spelers
            move_players = True

    # Bepaal het aantal teams als niet opgegeven
    if num_teams <= 0:
        num_teams = len(members) // 4 if len(members) >= 4 else 1

    num_teams = min(num_teams, len(members))
    teams = [[] for _ in range(num_teams)]
    for i, member in enumerate(members):
        teams[i % num_teams].append(member)

    # Zoek het tekstkanaal "teamify"
    text_channel = discord.utils.get(guild.text_channels, name="teamify")
    if not text_channel:
        await ctx.send("Het kanaal 'teamify' bestaat niet!")
        return

    message = f"Willekeurige teams uit {voice_channel.name}:\n\n"
    category = discord.utils.get(guild.categories, name="Temporary Teams")
    if not category:
        category = await guild.create_category("Temporary Teams")

    temp_channels = []

    for i, team in enumerate(teams, start=1):
        team_names = ', '.join([member.mention for member in team])
        message += f"**Team {i}:** {team_names}\n"

        if move_players:
            temp_channel = await guild.create_voice_channel(f"Squad {i}", category=category)
            temp_channels.append(temp_channel)
            for member in team:
                await member.move_to(temp_channel)

    await text_channel.send(message)
    await ctx.send("Teams zijn gepost in #teamify!" + (" Spelers zijn verplaatst naar tijdelijke kanalen." if move_players else ""))

    # Controleer continu of de kanalen leeg zijn en verwijder ze
    if move_players:
        while temp_channels:
            await asyncio.sleep(60)  # Controleer elke minuut
            for channel in temp_channels[:]:
                if len(channel.members) == 0:
                    if channel in guild.voice_channels:  # Controleer of het kanaal nog bestaat
                        await channel.delete()
                        temp_channels.remove(channel)
                        await ctx.send(f"Kanaal {channel.name} is opgeruimd omdat het leeg was!")

@bot.command()
async def whoisbest(ctx, category="Casual", matchesback=18):


    if category.lower() == "help":
        help_message = (
            "**Gebruik van het commando `whoisbest`:**\n"
            "`!whoisbest [category] [matchesback]`\n\n"
            "**Parameters:**\n"
            "`category` - De categorie van de stats, bijv. 'Casual' of 'Ranked'. Niet hoofdlettergevoelig.\n"
            "`matchesback` - Het minimum aantal matches dat een speler gespeeld moet hebben om mee te tellen (standaard 18).\n\n"
            "**Voorbeeld:**\n"
            "`!whoisbest Casual 18`\n"
            "Laat de top 3 spelers zien op basis van winratio en gemiddelde damage in de Casual categorie met minimaal 18 matches.\n\n"
            "Typ `!whoisbest help` om deze uitleg opnieuw te zien."
        )
        await ctx.send(help_message)
        return


    # Bestandspad
    file_path = os.path.join("..", "data", "player_last_stats.json")
    
    try:
        # JSON-bestand lezen
        with open(file_path, "r", encoding="utf-8") as file:
            data = json.load(file)

        # Mapping maken (lowercase -> originele categorie)
        category_mapping = {cat.lower(): cat for cat in data.keys()}

        # Zet de opgegeven category om naar lowercase
        lower_category = category.lower()

        if lower_category not in category_mapping:
            available_categories = ', '.join(data.keys())
            await ctx.send(f"Ongeldige categorie '{category}'! Beschikbare categorieën: {available_categories}")
            return
        
        # Gebruik de juiste (originele) categorie naam uit de mapping
        actual_category = category_mapping[lower_category]

        players = [player for player in data.get(actual_category, []) if player.get("matches", 0) >= matchesback]

        if not players:
            await ctx.send(f"Geen spelersstatistieken gevonden voor '{actual_category}' met minimaal {matchesback} gespeelde matches!")
            return

        # Sorteer spelers op winratio (aflopend)
        top_winratio = sorted(players, key=lambda x: x.get("winratio", 0), reverse=True)[:3]

        # Sorteer spelers op gemiddelde damage (aflopend)
        top_ahd = sorted(players, key=lambda x: x.get("ahd", 0), reverse=True)[:3]

        # Bouw het bericht op
        message = f"**\U0001F3C6 Top 3 Winratio ({actual_category})**\n"
        for i, player in enumerate(top_winratio, start=1):
            message += f"{i}. **{player['playername']}** - {player['winratio']:.2f}%\n"

        message += f"\n**\U0001F480 Top 3 AHD ({actual_category})**\n"
        for i, player in enumerate(top_ahd, start=1):
            message += f"{i}. **{player['playername']}** - {player['ahd']:.2f}\n"

        await ctx.send(message)

    except Exception as e:
        await ctx.send(f"Fout bij het laden van de statistieken: {str(e)}")

@bot.event        
async def on_voice_state_update(member, before, after):
    logging_channel = discord.utils.get(member.guild.text_channels, name="logging")
    
    if not logging_channel:
        return
    if (before.channel and before.channel.name == "GOD_CHANNEL") or (after.channel and after.channel.name == "GOD_CHANNEL"):
        return  # Als het God_channel is, doe niks
    
    if before.channel is None and after.channel is not None:
        # Lid joint een voice channel
        await logging_channel.send(f"🔊 {member.mention} is gejoined in voice kanaal: **{after.channel.name}**")
    elif before.channel is not None and after.channel is None:
        # Lid verlaat een voice channel
        await logging_channel.send(f"🔇 {member.mention} heeft het voice kanaal **{before.channel.name}** verlaten.")
    elif before.channel != after.channel:
        # Lid switched van voice kanaal
        await logging_channel.send(f"🔄 {member.mention} is van **{before.channel.name}** naar **{after.channel.name}** gegaan.")

@bot.event
async def on_member_join(member):
    logging_channel = discord.utils.get(member.guild.text_channels, name="raadhuisplein")
    if logging_channel:
        welcome_message = (
            f"🎉 Welcome {member.mention} to **{member.guild.name}**!\n\n"
            "👋 We're glad to have you here.\n"
            "👉 Want to jump right in? Type `!iamgamer` in the chat and you'll get the **Tourists** role.\n"
            "With that role you can join the fun and games with everyone else. 🎮\n"
            "Use !dtch_help for more info\n\n"
            "Enjoy your stay and have a great time! 🚀"
        )
        await logging_channel.send(welcome_message)

@bot.event
async def on_member_remove(member):
    logging_channel = discord.utils.get(member.guild.text_channels, name="raadhuisplein")
    if logging_channel:
        await logging_channel.send(f"😢 {member.name} heeft de server verlaten. We zullen je missen!")

@bot.command()
async def moveall(ctx):
    # Controleer of het commando in het juiste kanaal wordt uitgevoerd
    if ctx.channel.name != "teamify":
        await ctx.send("Dit commando kan alleen worden gebruikt in het #teamify tekstkanaal.")
        return
    
    guild = ctx.guild
    teamify_channel = discord.utils.get(guild.voice_channels, name="teamify")
    
    if not teamify_channel:
        await ctx.send("Het teamify voice-kanaal bestaat niet!")
        return
    
    moved_members = 0
    for channel in guild.voice_channels:
        if channel != teamify_channel:
            for member in channel.members:
                try:
                    await member.move_to(teamify_channel)
                    moved_members += 1
                except Exception as e:
                    await ctx.send(f"Kon {member.mention} niet verplaatsen: {e}")
    
    if moved_members > 0:
        await ctx.send(f"{moved_members} speler(s) zijn verplaatst naar het teamify kanaal.")
    else:
        await ctx.send("Er waren geen spelers om te verplaatsen.")
@bot.command()
async def iamgamer(ctx):
    role = discord.utils.get(ctx.guild.roles, name="Tourists")
    if role is None:
        await ctx.send("De rol **Tourists** bestaat niet!")
        return
    
    try:
        await ctx.author.add_roles(role)
        await ctx.send(f"✅ {ctx.author.mention}, je bent nu een **Tourist**! Veel plezier! 🎮")
    except Exception as e:
        await ctx.send(f"Er is iets misgegaan bij het toekennen van de rol: {e}")
@bot.command(name="dtch_help", aliases=["commands"])
async def dtch_help_command(ctx):
    embed = discord.Embed(
        title="📖 DTCH Bot Command Help",
        description="Here’s a list of all available commands and how to use them:",
        color=discord.Color.blue()
    )

    embed.add_field(
        name="👉 !teamify",
        value=(
            "`!teamify` - Split players into random teams of max 4.\n"
            "`!teamify <number_of_teams>` - Split players into a given number of teams.\n"
            "`!teamify <number_of_teams> move` - Split & move players into temporary voice channels.\n"
            "`!teamify move` - Auto split & move players.\n"
            "🔹 Works only in the **#teamify** channel."
        ),
        inline=False
    )

    embed.add_field(
        name="👉 !moveall",
        value="`!moveall` - Moves all players from other voice channels into the **teamify** channel.",
        inline=False
    )

    embed.add_field(
        name="👉 !whoisbest",
        value=(
            "`!whoisbest [category] [matchesback]`\n"
            "Shows the top 3 players based on win ratio and average damage.\n"
            "`category` = e.g. Casual, Ranked\n"
            "`matchesback` = minimum matches required (default: 18)\n"
            "Example: `!whoisbest Casual 18`"
        ),
        inline=False
    )

    embed.add_field(
        name="👉 !iamgamer",
        value="`!iamgamer` - Gives you the **Tourists** role 🎮 so you can join games and unlock more fun.",
        inline=False
    )

    embed.set_footer(text="✨ For advanced options, use: !teamify help or !whoisbest help")

    await ctx.send(embed=embed)
bot.run(token)
