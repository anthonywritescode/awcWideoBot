from __future__ import annotations

import json
import os
import re

import discord
from bot.main import Config
from bot.plugins.youtube_playlist_search import _msg
from discord.ext import commands


client = commands.Bot(command_prefix='!')
token = os.environ['DISCORD_BOT_TOKEN']


@client.event
async def on_ready():
    await client.change_presence(
        status=discord.Status.idle,
        activity=discord.Game('Listening to !explains, !faq, and !puzzles'),
    )
    print('Bot is ready.')


@client.command()
async def ping(ctx):
    await ctx.send(f'🏓 Pong with {str(round(client.latency, 2))}')


@client.command(name='whoami')
async def whoami(ctx):
    await ctx.send(f'You are {ctx.message.author.name}')


@client.command(name='explains')
async def explains(ctx):
    # config for heroku
    config = Config(**json.loads(os.environ['CONFIG']))

    # config for local
    # with open('config.json') as f:
    #   config = Config(**json.load(f))

    line = str(ctx.message.content)
    search_term = re.sub('!explains', '', line)
    get_msg = await _msg(config, 'explains', search_term)

    ESCAPE = {
        ord('\\'): r'\\', ord('_'): r'\_',
        ord('['): r'\[', ord(']'): r'\]',
    }

    def video_title(s: str) -> str:
        if not s.find('https'):
            return f'{s}'
        s2 = s.split('https')
        if len(s2) == 2:
            return f'{s2[0].translate(ESCAPE)}https{s2[1]}'
        else:
            return f'{s2[0].translate(ESCAPE)}https{s2[1]}https{s2[2]}'

    string = video_title(get_msg)
    index1 = string.find('https')
    index2 = string.find(' ', index1)

    if string.find('https', index2) != -1:
        index3 = string.find('https', index2)
        string2 = string[:index1] + string[index1:index2] \
            + string[index2:index3] + '<' + string[index3:] + '>'
    else:
        string2 = string[:index1] + string[index1:]

    await ctx.send(
        f'{ctx.message.author.mention}, '
        f'here you go: {string2}',
    )


@client.command(name='faq')
async def faq(ctx):
    # config for heroku
    config = Config(**json.loads(os.environ['CONFIG']))

    # config for local
    # with open('config.json') as f:
    #   config = Config(**json.loads(f))

    line = str(ctx.message.content)
    search_term = re.sub('!faq', '', line)
    get_msg = await _msg(config, 'faq', search_term)

    ESCAPE = {
        ord('\\'): r'\\', ord('_'): r'\_',
        ord('['): r'\[', ord(']'): r'\]',
    }

    def video_title(s: str) -> str:
        return s.strip().translate(ESCAPE)

    await ctx.send(
        f'{ctx.message.author.mention}, '
        f'here you go: <{video_title(get_msg)}>',
    )


@client.command(name='puzzles')
async def puzzles(ctx):
    # config for heroku
    config = Config(**json.loads(os.environ['CONFIG']))

    # config for local
    # with open('config.json') as f:
    #   config = Config(**json.loads(f))

    line = str(ctx.message.content)
    search_term = re.sub('!puzzles', '', line)
    get_msg = await _msg(config, 'puzzles', search_term)

    ESCAPE = {
        ord('\\'): r'\\', ord('_'): r'\_',
        ord('['): r'\[', ord(']'): r'\]',
    }

    def vid_link(s: str) -> str:
        return s.strip().translate(ESCAPE)

    link1, link2 = vid_link(get_msg).split('list')

    await ctx.send(
        f'{ctx.message.author.mention}, '
        f'here you go: <{link1}list{link2}>',
    )


@client.command(name='udp')
async def udp(ctx):
    await ctx.send(
        '"udp your questions,'
        ' don\'t tcp your questions" - marsha_socks',
    )

client.run(token)
