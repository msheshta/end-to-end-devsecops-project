
FROM node:24-alpine3.22

RUN npm install -g npm@12.2.0


ENV NODE_ENV=production

WORKDIR /app

COPY package.json ./
COPY src ./src
COPY public ./public 

USER node

EXPOSE 3000

CMD ["node", "src/server.js"]