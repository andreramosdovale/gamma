# --- Stage 1: Build ---
# Use a full Node.js image to install dependencies and build the project
FROM node:20-alpine AS builder

# Set the working directory inside the container
WORKDIR /usr/src/app

# Copy package.json and package-lock.json to the working directory
COPY package*.json ./

# Install all dependencies
RUN npm install

# Copy the rest of the application code
COPY . .

# Build the TypeScript application into JavaScript
RUN npm run build

# --- Stage 2: Production ---
# Use a lighter Node.js image, as we no longer need development dependencies
FROM node:20-alpine

# Argument to set NODE_ENV, defaults to 'production'
ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

WORKDIR /usr/src/app

# Copy package.json and package-lock.json again
COPY package*.json ./

# Install ONLY production dependencies
RUN npm install --omit=dev

# Copy build artifacts from the 'builder' stage
COPY --from=builder /usr/src/app/dist ./dist

# Expose the port the application will run on (will be defined in docker-compose)
# EXPOSE 3000

# Command to start the application in production
CMD ["node", "dist/main"]