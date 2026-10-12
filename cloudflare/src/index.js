import { DurableObject } from 'cloudflare:workers';

// The rooms of online games: one Durable Object per room code, relaying what
// each phone says to the others over WebSockets. Nothing is stored: the
// host's phone runs the game.

const ROOM_PATH = /^\/room\/([A-Z]{4})$/;
const PHONE_ID = /^[\w-]{1,64}$/;
const MAX_PHONES = 16;
const MAX_MESSAGE_LENGTH = 64 * 1024;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const room = ROOM_PATH.exec(url.pathname)?.[1];
    if (!room) return new Response('not found', { status: 404 });
    if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') {
      return new Response('expected a websocket', { status: 426 });
    }
    if (!originAllowed(request.headers.get('Origin'), env.ALLOWED_ORIGINS)) {
      return new Response('origin not allowed', { status: 403 });
    }
    if (!PHONE_ID.test(url.searchParams.get('id') ?? '')) {
      return new Response('missing id', { status: 400 });
    }
    return env.ROOMS.get(env.ROOMS.idFromName(room)).fetch(request);
  },
};

function originAllowed(origin, allowed) {
  if (!origin) return true;
  let host;
  try {
    host = new URL(origin).hostname;
  } catch {
    return false;
  }
  if (host === 'localhost' || host === '127.0.0.1') return true;
  return (allowed ?? '')
    .split(',')
    .map((entry) => entry.trim())
    .includes(origin);
}

export class Room extends DurableObject {
  async fetch(request) {
    const id = new URL(request.url).searchParams.get('id');
    // A phone that comes back takes the place of the line it lost.
    for (const stale of this.ctx.getWebSockets(id)) {
      stale.close(4000, 'replaced');
    }
    if (this.ctx.getWebSockets().length >= MAX_PHONES) {
      return new Response('room full', { status: 429 });
    }
    const { 0: client, 1: server } = new WebSocketPair();
    // Hibernation: the room costs nothing while nobody speaks.
    this.ctx.acceptWebSocket(server, [id]);
    return new Response(null, { status: 101, webSocket: client });
  }

  webSocketMessage(socket, message) {
    if (typeof message !== 'string' || message.length > MAX_MESSAGE_LENGTH) {
      return;
    }
    let envelope;
    try {
      envelope = JSON.parse(message);
    } catch {
      return;
    }
    const body = envelope?.body;
    if (body === null || typeof body !== 'object') return;
    const to = typeof envelope.to === 'string' ? envelope.to : undefined;
    // Who speaks is what the room knows, not what the message claims.
    const [from] = this.ctx.getTags(socket);
    const relayed = JSON.stringify({ from, body });
    for (const other of this.ctx.getWebSockets(to)) {
      if (other === socket) continue;
      try {
        other.send(relayed);
      } catch {
        // That phone is gone; the game copes with lost messages.
      }
    }
  }

  webSocketClose(socket, code) {
    try {
      // 1005 and 1006 only describe a close, they cannot be sent.
      socket.close(code === 1005 || code === 1006 ? 1000 : code);
    } catch {
      // Already closed.
    }
  }
}
