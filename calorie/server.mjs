import { createServer } from 'node:http'
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import Anthropic from '@anthropic-ai/sdk'

const here = dirname(fileURLToPath(import.meta.url))
const PORT = Number(process.env.PORT ?? 4317)

const client = new Anthropic()

const SYSTEM = `You are the parser behind a conversational food log. The user types what they ate in plain English; you turn it into structured items and write one short line back to them.

Return ONLY a JSON object. No markdown fences, no commentary outside the JSON.

{"note": "...", "items": [{"name": "Oatmeal", "calories": 158, "protein": 6, "carbs": 27, "fat": 3, "servingAmount": 1, "servingUnit": "cup", "mealType": "breakfast", "source": "database"}]}

PARSING
- Split compound input into separate items. "oatmeal with blueberries and a latte" is three items, not one. A dish that a person thinks of as one thing stays one item — a chicken burrito or a caesar salad is one item, not a list of ingredients.
- name: short and capitalized, no quantity in it. "Oatmeal", never "1 cup of oatmeal".
- calories, protein, carbs, fat: whole numbers for the amount actually eaten, already scaled to servingAmount. Not per-unit values. Macros should reconcile roughly with calories at 4/4/9, and should not be zero for a food that plainly contains them.
- servingAmount and servingUnit: the quantity this row represents, in the unit a person would use out loud — cup, oz, g, slice, piece, bowl, tbsp, can, medium, serving.
- mealType: breakfast, lunch, dinner, or snack. Infer it from the local time you are given and from the food itself. A protein bar at 3pm is a snack; eggs alone at 11am are breakfast.
- When the user gives no quantity, pick the ordinary serving a person would actually eat, and say in the note that you assumed it.
- source: "database" when you are reporting a standard well-known value for a plain food or a chain menu item. "estimated" when you are guessing — homemade cooking, unknown preparation, a restaurant plate, anything you had to reason your way to.

THE NOTE
This is the voice of the app. It renders as one small grey line under what the user typed.
- One or two sentences, maximum. Often just three words.
- State assumptions plainly: "Logged breakfast — I assumed a cup of oats and whole milk in the latte."
- When an estimate is shaky, offer the correction path: "Estimated it as a standard deli sandwich, about 390. Say the word if it was a footlong and I'll redo it."
- If this reads like the last meal of the day, close the loop with a fact drawn from the day context you were given: "Good dinner. 86g of protein on the day and you finished 168 under."
- When there is nothing worth saying, say "Logged." and stop.
- Never use an exclamation mark. Never praise the user for logging. Never give nutrition advice they did not ask for. No emoji. Do not list the items back — they are already on screen.`

function contextLine(b) {
  const parts = [
    `Local time: ${b.localTime}.`,
    `Before this entry, the day has ${Math.round(b.caloriesSoFar ?? 0)} calories and ${Math.round(b.proteinSoFar ?? 0)}g of protein logged.`,
    `Their goal is ${b.goal} calories and ${b.proteinTarget}g of protein.`,
  ]
  return parts.join(' ')
}

function stripFences(text) {
  const t = text.trim()
  if (!t.startsWith('```')) return t
  return t.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/, '').trim()
}

const MEALS = ['breakfast', 'lunch', 'dinner', 'snack']
const int = (v) => (Number.isFinite(Number(v)) ? Math.max(0, Math.round(Number(v))) : 0)

function normalize(raw) {
  if (!raw || !Array.isArray(raw.items) || raw.items.length === 0) {
    throw new Error('no items in response')
  }
  return {
    note: typeof raw.note === 'string' ? raw.note.trim() : 'Logged.',
    items: raw.items.map((it) => {
      const amount = Number(it.servingAmount)
      return {
        name: String(it.name ?? 'Item').trim(),
        calories: int(it.calories),
        protein: int(it.protein),
        carbs: int(it.carbs),
        fat: int(it.fat),
        servingAmount: Number.isFinite(amount) && amount > 0 ? amount : 1,
        servingUnit: String(it.servingUnit ?? 'serving').trim(),
        mealType: MEALS.includes(it.mealType) ? it.mealType : 'snack',
        source: it.source === 'database' ? 'database' : 'estimated',
      }
    }),
  }
}

async function parse(body) {
  const message = await client.messages.create({
    model: 'claude-sonnet-4-6',
    max_tokens: 1000,
    system: SYSTEM,
    messages: [
      {
        role: 'user',
        content: `${contextLine(body)}\n\nThey typed: ${body.text}`,
      },
    ],
  })
  const text = message.content
    .filter((b) => b.type === 'text')
    .map((b) => b.text)
    .join('')
  return normalize(JSON.parse(stripFences(text)))
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = ''
    req.on('data', (c) => {
      data += c
      if (data.length > 1e6) reject(new Error('body too large'))
    })
    req.on('end', () => resolve(data))
    req.on('error', reject)
  })
}

const server = createServer(async (req, res) => {
  if (req.method === 'POST' && req.url === '/api/parse') {
    try {
      const body = JSON.parse(await readBody(req))
      if (!body.text || !String(body.text).trim()) throw new Error('empty input')
      const parsed = await parse(body)
      res.writeHead(200, { 'content-type': 'application/json' })
      res.end(JSON.stringify(parsed))
    } catch (err) {
      const missingKey = /api.?key/i.test(err?.message ?? '')
      const status = missingKey ? 401 : 502
      const detail = missingKey
        ? 'No ANTHROPIC_API_KEY set on the server.'
        : (err?.message ?? 'Parse failed.')
      console.error('[parse]', detail)
      res.writeHead(status, { 'content-type': 'application/json' })
      res.end(JSON.stringify({ error: detail }))
    }
    return
  }

  if (req.method === 'GET' && (req.url === '/' || req.url === '/index.html')) {
    try {
      const html = await readFile(join(here, 'index.html'))
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' })
      res.end(html)
    } catch {
      res.writeHead(500).end('index.html missing')
    }
    return
  }

  res.writeHead(404).end('not found')
})

server.listen(PORT, () => {
  console.log(`what did you eat  ->  http://localhost:${PORT}`)
  if (!process.env.ANTHROPIC_API_KEY) {
    console.log('warning: ANTHROPIC_API_KEY is not set — parsing will return an inline error.')
  }
})
