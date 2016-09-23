local class = require "middleclass"
local tilesize = require "tilesize"
local Bullet = require "bullet"
local Timer = require "timer"
local Enemy = class("Enemy")

local function aabb(bullet, x, y, w, h)
	return bullet.x1 + bullet.width > x and bullet.x1 < x + w and
			bullet.y1 + bullet.height > y and bullet.y1 < y + h
end

function Enemy:initialize(x, y, room)
	self.x = x
	self.y = y
	self.width = tilesize / 1
	self.height = self.width
	self.kind = "enemy"
	self.maxHealth = 75
	self.health = self.maxHealth
	self.rof = math.random(.6, 1.8)

	self.room = room
	self.reachedGoal = true
	self.goalX = 0
	self.goalY = 0
	self.distance = 0
	self.dx = 0
	self.dy = 0
	self.directionX, self.directionY = 0, 0
	self.speed = 100

	self.canShoot = true
	self.canSee = false
	self.shootTimer = Timer:new(self.rof)
	self.bullet = {
		list = {},
		width = 2,
		height = 2,
		speed = 300,
		minAtkPwr = 4,
		maxAtkPwr = 12
	}

	self.fovDistance = 325
end

function Enemy:update(dt, world, drawList, player)
	self:updateTimer(dt)
	self:updateBullets(dt, world, drawList, player)
	self:updateFov(player.x, player.y)
	self:updatePosition(dt)
end

function Enemy:updateFov(x, y)
	local cx = self.x + self.width / 2
	local cy = self.y + self.height / 2

	local distance = math.sqrt((cx - x)^2 + (cy - y)^2)
	if distance <= self.fovDistance then
		self.canSee = true
	else
		self.canSee = false
	end
end

function Enemy:updatePosition(dt)
	if self.reachedGoal then
		self.goalX, self.goalY = self:newPosition()

		self.directionX = self.dx / self.distance
		self.directionY = self.dy / self.distance

		self.reachedGoal = false
	end

	self.x = self.x + self.directionX * self.speed * dt
	self.y = self.y + self.directionY * self.speed * dt

	if self.directionX < 0 and self.directionY < 0 then
		if self.x < self.goalX and self.y < self.goalY then
			self.reachedGoal = true
		end
	end
	if self.directionX < 0 and self.directionY > 0 then
		if self.x < self.goalX and self.y > self.goalY then
			self.reachedGoal = true
		end
	end
	if self.directionX > 0 and self.directionY < 0 then
		if self.x > self.goalX and self.y < self.goalY then
			self.reachedGoal = true
		end
	end
	if self.directionX > 0 and self.directionY > 0 then
		if self.x > self.goalX and self.y > self.goalY then
			self.reachedGoal = true
		end
	end
end

function Enemy:newPosition()
	local x = math.random(self.room.x + 1, self.room.x + self.room.width - 1) * tilesize
	local y = math.random(self.room.y + 1, self.room.y + self.room.height - 1) * tilesize

	self.distance = math.sqrt((x-self.x)^2 + (y-self.y)^2)
	self.dx = x - self.x
	self.dy = y - self.y

	return x, y
end

function Enemy:updateTimer(dt)
	self.shootTimer:update(dt, function()
		self.canShoot = true
	end)
end

local remove = table.remove
function Enemy:updateBullets(dt, world, drawList, player)
	for i = #self.bullet.list, 1, -1 do
		local bullet = self.bullet.list[i]
		bullet:update(dt)
		world:update(bullet, bullet.x1, bullet.y1)

		for j = 1, #drawList do
			local p = drawList[j]
			if p.num == 1 then
				local x, y = p.x * tilesize, p.y * tilesize
				local w, h = tilesize, tilesize

				if aabb(bullet, x, y, w, h) then
					remove(self.bullet.list, i)
					world:remove(bullet)
					break
				end
			end
		end

		if aabb(bullet, player.x, player.y, player.width, player.height) then
			player:damagePlayer(bullet.atkPwr)
			remove(self.bullet.list, i)
			world:remove(bullet)
			break
		end
	end
end

function Enemy:removeBullets(world)
	if #self.bullet.list > 0 then
		for i = #self.bullet.list, 1, -1 do
			local bullet = self.bullet.list[i]
			remove(self.bullet.list, i)
			world:remove(bullet)
			break
		end
		self:removeBullets(world)
	end
end

function Enemy:fireBullets(x, y, world)
	if self.canShoot and self.canSee then
		local w, h = 4, 4
		local atkPwr = math.random(self.bullet.minAtkPwr, self.bullet.maxAtkPwr)
		local bullet = Bullet:new(self.x + self.width / 2, self.y + self.height / 2,
			x, y, w, h, atkPwr, self.bullet.speed)
		self.bullet.list[#self.bullet.list+1] = bullet
		world:add(bullet, bullet.x1, bullet.y1, w, h)

		self.canShoot = false
	end
end

function Enemy:hurtEnemy(atkPwr)
	self.health = self.health - atkPwr
end

function Enemy:draw()
	-- health bar
	love.graphics.setColor(255,0,0)
	local w = 0
	for i = 1, self.health do
		w = w + .5 
	end
	love.graphics.rectangle("fill", self.x - 10, self.y - 12, w, 6)

	love.graphics.setColor(255,0,255)
	love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

	for i = 1, #self.bullet.list do
		local bullet = self.bullet.list[i]
		love.graphics.setColor(0,255,255)
		love.graphics.rectangle("fill", bullet.x1, bullet.y1, bullet.width, bullet.height)
	end
end

return Enemy