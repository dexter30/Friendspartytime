const screens = {
  menu: document.getElementById("main-menu"),
  select: document.getElementById("character-select"),
  arena: document.getElementById("arena-screen"),
};

const startArenaButton = document.getElementById("start-arena-button");
const beginMatchButton = document.getElementById("begin-match-button");
const backToMenuButton = document.getElementById("back-to-menu-button");
const returnMenuButton = document.getElementById("return-menu-button");
const p1Options = document.getElementById("p1-options");
const p2Options = document.getElementById("p2-options");
const hudP1 = document.getElementById("hud-p1");
const hudP2 = document.getElementById("hud-p2");

const canvas = document.getElementById("arena-canvas");
const ctx = canvas.getContext("2d");

const STAGE = {
  x: -420,
  y: 0,
  width: 840,
  height: 34,
  blastLeft: -760,
  blastRight: 760,
  blastTop: -520,
  blastBottom: 470,
};

const FIGHTERS = [
  {
    id: "nova-ninja",
    name: "Nova Ninja",
    tag: "Neon Roundhouse",
    shape: "circle",
    color: "#4de4ff",
    eyeColor: "#001e33",
    stats: { speed: 0.74, jump: 15.6, weight: 1.02, power: 1.0 },
  },
  {
    id: "brick-blade",
    name: "Brick Blade",
    tag: "Heavy Square Hero",
    shape: "square",
    color: "#ff6f86",
    eyeColor: "#2d0814",
    stats: { speed: 0.62, jump: 14.3, weight: 1.22, power: 1.18 },
  },
  {
    id: "prism-pouncer",
    name: "Prism Pouncer",
    tag: "Tri-Wing Trickster",
    shape: "triangle",
    color: "#ffd468",
    eyeColor: "#2d2500",
    stats: { speed: 0.8, jump: 16.8, weight: 0.9, power: 0.96 },
  },
  {
    id: "orbit-owl",
    name: "Orbit Owl",
    tag: "Diamond Dash Duelist",
    shape: "diamond",
    color: "#af89ff",
    eyeColor: "#240f4f",
    stats: { speed: 0.7, jump: 15, weight: 1.0, power: 1.08 },
  },
];

const state = {
  selected: { p1: null, p2: null },
  keys: new Set(),
  players: [],
  particles: [],
  camera: { x: 0, y: -110, zoom: 1, shake: 0, shakePower: 0 },
  mode: "menu",
  winnerMessageTimer: 0,
  running: false,
  previousMs: 0,
};

const CONTROL_MAP = [
  { left: "KeyA", right: "KeyD", jump: "KeyW", light: "KeyF", heavy: "KeyG" },
  { left: "KeyJ", right: "KeyL", jump: "KeyI", light: "KeyO", heavy: "KeyP" },
];

function switchScreen(nextMode) {
  state.mode = nextMode;
  Object.values(screens).forEach((screen) => screen.classList.remove("active"));
  if (nextMode === "menu") screens.menu.classList.add("active");
  if (nextMode === "select") screens.select.classList.add("active");
  if (nextMode === "arena") screens.arena.classList.add("active");
}

function makePreviewSVG(fighter) {
  const shape = (() => {
    if (fighter.shape === "circle") return `<circle cx="34" cy="25" r="18" fill="${fighter.color}" />`;
    if (fighter.shape === "square") return `<rect x="16" y="7" width="36" height="36" rx="4" fill="${fighter.color}" />`;
    if (fighter.shape === "triangle") return `<polygon points="34,6 54,43 14,43" fill="${fighter.color}" />`;
    return `<polygon points="34,4 55,25 34,46 13,25" fill="${fighter.color}" />`;
  })();
  return `
  <svg class="fighter-preview" viewBox="0 0 68 50" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
    ${shape}
    <circle cx="28" cy="23" r="3.6" fill="${fighter.eyeColor}" />
    <circle cx="40" cy="23" r="3.6" fill="${fighter.eyeColor}" />
  </svg>`;
}

function renderFighterCards(container, playerKey) {
  container.innerHTML = "";
  FIGHTERS.forEach((fighter) => {
    const card = document.createElement("button");
    card.type = "button";
    card.className = "fighter-card";
    card.innerHTML = `
      ${makePreviewSVG(fighter)}
      <div class="fighter-name">${fighter.name}</div>
      <div class="fighter-tag">${fighter.tag}</div>`;
    card.addEventListener("click", () => {
      state.selected[playerKey] = fighter.id;
      renderSelectionState();
    });
    container.appendChild(card);
  });
}

function renderSelectionState() {
  const p1Cards = [...p1Options.children];
  const p2Cards = [...p2Options.children];
  p1Cards.forEach((card, index) => {
    card.classList.toggle("selected", FIGHTERS[index].id === state.selected.p1);
  });
  p2Cards.forEach((card, index) => {
    card.classList.toggle("selected", FIGHTERS[index].id === state.selected.p2);
  });
  beginMatchButton.disabled = !(state.selected.p1 && state.selected.p2);
}

function createPlayer(fighter, slot) {
  const spawnX = slot === 0 ? -220 : 220;
  return {
    slot,
    fighter,
    x: spawnX,
    y: -150,
    vx: 0,
    vy: 0,
    width: 62,
    height: 62,
    facing: slot === 0 ? 1 : -1,
    speed: fighter.stats.speed,
    jumpForce: fighter.stats.jump,
    weight: fighter.stats.weight,
    power: fighter.stats.power,
    damage: 0,
    stocks: 5,
    onGround: false,
    jumpsUsed: 0,
    attackCooldown: 0,
    hurtTimer: 0,
    hitFlash: 0,
    invuln: 45,
    attackWindup: 0,
    queuedAttack: null,
    attackDidHit: false,
  };
}

function beginMatch() {
  const p1Fighter = FIGHTERS.find((f) => f.id === state.selected.p1);
  const p2Fighter = FIGHTERS.find((f) => f.id === state.selected.p2);
  if (!p1Fighter || !p2Fighter) return;
  state.players = [createPlayer(p1Fighter, 0), createPlayer(p2Fighter, 1)];
  state.particles = [];
  state.winnerMessageTimer = 0;
  switchScreen("arena");
}

function drawShapePlayer(player) {
  const bodyX = player.x;
  const bodyY = player.y - player.height * 0.5;
  const w = player.width;
  const h = player.height;
  ctx.save();
  if (player.hitFlash > 0) {
    ctx.shadowColor = "rgba(255, 255, 255, 0.7)";
    ctx.shadowBlur = 18;
  }
  ctx.fillStyle = player.fighter.color;
  if (player.fighter.shape === "circle") {
    ctx.beginPath();
    ctx.arc(bodyX, bodyY, w * 0.48, 0, Math.PI * 2);
    ctx.fill();
  } else if (player.fighter.shape === "square") {
    ctx.fillRect(bodyX - w * 0.5, bodyY - h * 0.5, w, h);
  } else if (player.fighter.shape === "triangle") {
    ctx.beginPath();
    ctx.moveTo(bodyX, bodyY - h * 0.55);
    ctx.lineTo(bodyX + w * 0.56, bodyY + h * 0.48);
    ctx.lineTo(bodyX - w * 0.56, bodyY + h * 0.48);
    ctx.closePath();
    ctx.fill();
  } else {
    ctx.beginPath();
    ctx.moveTo(bodyX, bodyY - h * 0.56);
    ctx.lineTo(bodyX + w * 0.56, bodyY);
    ctx.lineTo(bodyX, bodyY + h * 0.56);
    ctx.lineTo(bodyX - w * 0.56, bodyY);
    ctx.closePath();
    ctx.fill();
  }

  const eyeOffsetX = 11 * player.facing;
  ctx.fillStyle = player.fighter.eyeColor;
  ctx.beginPath();
  ctx.arc(bodyX - eyeOffsetX, bodyY - 4, 4.4, 0, Math.PI * 2);
  ctx.arc(bodyX + eyeOffsetX, bodyY - 4, 4.4, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

function makeAttack(player, type) {
  if (player.attackCooldown > 0 || player.queuedAttack) return;
  if (type === "light") {
    player.attackWindup = 5;
    player.attackCooldown = 18;
    player.queuedAttack = {
      radius: 68,
      force: 8.8,
      vertical: 6.5,
      baseDamage: 9.5,
      shake: 5,
      particles: 8,
    };
  } else {
    player.attackWindup = 14;
    player.attackCooldown = 42;
    player.queuedAttack = {
      radius: 88,
      force: 12.8,
      vertical: 10.5,
      baseDamage: 16.5,
      shake: 9,
      particles: 15,
    };
  }
}

function updatePlayer(player, controls) {
  if (player.stocks <= 0) return;
  const move = (state.keys.has(controls.right) ? 1 : 0) - (state.keys.has(controls.left) ? 1 : 0);
  if (Math.abs(move) > 0) {
    player.vx += move * 0.66 * player.speed;
    player.facing = move > 0 ? 1 : -1;
  } else {
    player.vx *= 0.86;
  }
  if (state.keys.has(controls.jump) && !controls.jumpConsumed) {
    if (player.onGround || player.jumpsUsed < 2) {
      player.vy = -player.jumpForce;
      player.onGround = false;
      player.jumpsUsed += 1;
      burstParticles(player.x, player.y, 6, "#d3f4ff");
    }
    controls.jumpConsumed = true;
  }
  if (!state.keys.has(controls.jump)) controls.jumpConsumed = false;

  if (state.keys.has(controls.light) && !controls.lightConsumed) {
    makeAttack(player, "light");
    controls.lightConsumed = true;
  }
  if (!state.keys.has(controls.light)) controls.lightConsumed = false;
  if (state.keys.has(controls.heavy) && !controls.heavyConsumed) {
    makeAttack(player, "heavy");
    controls.heavyConsumed = true;
  }
  if (!state.keys.has(controls.heavy)) controls.heavyConsumed = false;

  player.vy += 0.7;
  player.vx *= 0.95;
  player.x += player.vx;
  player.y += player.vy;

  const halfW = player.width * 0.5;
  const feetY = player.y + player.height * 0.02;
  if (
    player.vy >= 0 &&
    feetY >= STAGE.y &&
    feetY <= STAGE.y + STAGE.height + 14 &&
    player.x + halfW > STAGE.x &&
    player.x - halfW < STAGE.x + STAGE.width
  ) {
    player.y = STAGE.y - player.height * 0.02;
    player.vy = 0;
    player.onGround = true;
    player.jumpsUsed = 0;
  } else {
    player.onGround = false;
  }

  player.attackCooldown = Math.max(0, player.attackCooldown - 1);
  player.hurtTimer = Math.max(0, player.hurtTimer - 1);
  player.hitFlash = Math.max(0, player.hitFlash - 1);
  player.invuln = Math.max(0, player.invuln - 1);

  if (player.attackWindup > 0) {
    player.attackWindup -= 1;
    if (player.attackWindup === 0 && player.queuedAttack) {
      executeAttack(player, player.queuedAttack);
      player.queuedAttack = null;
    }
  }
}

function executeAttack(attacker, attack) {
  const defender = state.players[attacker.slot === 0 ? 1 : 0];
  if (defender.invuln > 0 || defender.stocks <= 0) return;
  const dx = defender.x - attacker.x;
  const dy = defender.y - attacker.y;
  const dist = Math.hypot(dx, dy);
  const facingCheck = Math.sign(dx || 1) === attacker.facing;
  if (dist > attack.radius || !facingCheck) return;

  const damageBoost = 1 + defender.damage * 0.012;
  const kb = (attack.force * attacker.power * damageBoost) / defender.weight;
  defender.vx = attacker.facing * kb;
  defender.vy = -attack.vertical - defender.damage * 0.02;
  defender.damage += attack.baseDamage * attacker.power;
  defender.hurtTimer = 12;
  defender.hitFlash = 6;
  defender.onGround = false;
  defender.invuln = 8;
  state.camera.shake = 8;
  state.camera.shakePower = attack.shake;
  burstParticles(defender.x, defender.y - 24, attack.particles, attacker.fighter.color);
}

function burstParticles(x, y, count, color) {
  for (let i = 0; i < count; i += 1) {
    state.particles.push({
      x,
      y,
      vx: (Math.random() - 0.5) * 8,
      vy: (Math.random() - 0.5) * 8 - 0.8,
      life: 20 + Math.random() * 22,
      color,
      size: 2 + Math.random() * 3,
    });
  }
}

function updateParticles() {
  state.particles.forEach((particle) => {
    particle.x += particle.vx;
    particle.y += particle.vy;
    particle.vy += 0.2;
    particle.vx *= 0.96;
    particle.life -= 1;
  });
  state.particles = state.particles.filter((particle) => particle.life > 0);
}

function checkKO(player) {
  if (player.stocks <= 0) return;
  const out =
    player.x < STAGE.blastLeft ||
    player.x > STAGE.blastRight ||
    player.y < STAGE.blastTop ||
    player.y > STAGE.blastBottom;
  if (!out) return;
  player.stocks -= 1;
  burstParticles(player.x, player.y, 24, "#ffffff");
  if (player.stocks <= 0) {
    player.vx = 0;
    player.vy = 0;
    return;
  }
  player.x = player.slot === 0 ? -250 : 250;
  player.y = -220;
  player.vx = 0;
  player.vy = 0;
  player.damage = 0;
  player.invuln = 80;
  player.jumpsUsed = 0;
}

function updateCamera() {
  const active = state.players.filter((p) => p.stocks > 0);
  if (active.length === 0) return;
  const midX = active.reduce((sum, p) => sum + p.x, 0) / active.length;
  const midY = active.reduce((sum, p) => sum + p.y, 0) / active.length;
  const distance = active.length > 1 ? Math.abs(active[0].x - active[1].x) : 0;
  const targetZoom = Math.max(0.75, Math.min(1.2, 1.15 - distance / 1400));
  state.camera.x += (midX - state.camera.x) * 0.08;
  state.camera.y += (midY - 120 - state.camera.y) * 0.08;
  state.camera.zoom += (targetZoom - state.camera.zoom) * 0.06;
  if (state.camera.shake > 0) state.camera.shake -= 1;
}

function drawArena() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  const shake = state.camera.shake > 0 ? state.camera.shakePower : 0;
  const shakeX = (Math.random() - 0.5) * shake;
  const shakeY = (Math.random() - 0.5) * shake;

  ctx.save();
  ctx.translate(canvas.width * 0.5 + shakeX, canvas.height * 0.5 + shakeY);
  ctx.scale(state.camera.zoom, state.camera.zoom);
  ctx.translate(-state.camera.x, -state.camera.y);

  const grad = ctx.createLinearGradient(0, -500, 0, 500);
  grad.addColorStop(0, "#2d2b5f");
  grad.addColorStop(1, "#100d1d");
  ctx.fillStyle = grad;
  ctx.fillRect(-1000, -600, 2000, 1200);

  ctx.fillStyle = "#6f4ac2";
  ctx.fillRect(STAGE.x, STAGE.y, STAGE.width, STAGE.height);
  ctx.fillStyle = "#9d7bff";
  ctx.fillRect(STAGE.x, STAGE.y, STAGE.width, 6);

  state.particles.forEach((particle) => {
    ctx.globalAlpha = Math.max(0, particle.life / 35);
    ctx.fillStyle = particle.color;
    ctx.fillRect(particle.x, particle.y, particle.size, particle.size);
  });
  ctx.globalAlpha = 1;

  state.players.forEach(drawShapePlayer);
  ctx.restore();
}

function updateHud() {
  const p1 = state.players[0];
  const p2 = state.players[1];
  hudP1.textContent = `${p1.fighter.name} | Damage ${Math.round(p1.damage)}% | Stocks ${"●".repeat(
    p1.stocks
  )}`;
  hudP2.textContent = `${p2.fighter.name} | Damage ${Math.round(p2.damage)}% | Stocks ${"●".repeat(
    p2.stocks
  )}`;
}

function drawWinnerOverlay() {
  const alive = state.players.filter((p) => p.stocks > 0);
  if (alive.length !== 1) return false;
  state.winnerMessageTimer += 1;
  if (state.winnerMessageTimer < 30) return true;
  const winner = alive[0];
  ctx.save();
  ctx.fillStyle = "rgba(10, 8, 20, 0.75)";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "#ffffff";
  ctx.textAlign = "center";
  ctx.font = "bold 46px Trebuchet MS";
  ctx.fillText(`${winner.fighter.name} Wins!`, canvas.width / 2, canvas.height / 2 - 10);
  ctx.font = "22px Trebuchet MS";
  ctx.fillStyle = "#d5c8ff";
  ctx.fillText("Press Main Menu to play again", canvas.width / 2, canvas.height / 2 + 38);
  ctx.restore();
  return true;
}

function tick(ms) {
  if (!state.running) return;
  const dt = Math.min(33, ms - state.previousMs);
  state.previousMs = ms;
  if (state.mode === "arena") {
    const steps = Math.max(1, Math.round(dt / 16));
    for (let i = 0; i < steps; i += 1) {
      updatePlayer(state.players[0], CONTROL_MAP[0]);
      updatePlayer(state.players[1], CONTROL_MAP[1]);
      checkKO(state.players[0]);
      checkKO(state.players[1]);
      updateParticles();
      updateCamera();
    }
    updateHud();
    drawArena();
    drawWinnerOverlay();
  }
  requestAnimationFrame(tick);
}

function toCharacterSelect() {
  switchScreen("select");
  renderSelectionState();
}

function returnToMenu() {
  switchScreen("menu");
  state.selected = { p1: null, p2: null };
  renderSelectionState();
}

function setupInput() {
  window.addEventListener("keydown", (event) => {
    if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"].includes(event.code)) {
      event.preventDefault();
    }
    state.keys.add(event.code);
  });
  window.addEventListener("keyup", (event) => {
    state.keys.delete(event.code);
  });
}

function setupUI() {
  renderFighterCards(p1Options, "p1");
  renderFighterCards(p2Options, "p2");
  renderSelectionState();
  startArenaButton.addEventListener("click", toCharacterSelect);
  beginMatchButton.addEventListener("click", beginMatch);
  backToMenuButton.addEventListener("click", returnToMenu);
  returnMenuButton.addEventListener("click", returnToMenu);
}

function boot() {
  setupUI();
  setupInput();
  switchScreen("menu");
  state.running = true;
  state.previousMs = performance.now();
  requestAnimationFrame(tick);
}

boot();
