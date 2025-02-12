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
    voice_channel = discord.utils.get(guild.voice_channels, name="Pubg_Random")

    if not voice_channel or len(voice_channel.members) == 0:
        await ctx.send("Er zijn geen mensen in het kanaal 'Pubg_Random' om teams van te maken!")
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
async def whoisbest(ctx):
    await ctx.send("Lanta is the best")

bot.run(token)
