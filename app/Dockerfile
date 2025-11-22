# Use an official Node.js runtime as a parent image
FROM node:18-alpine

# Set the working directory in the container
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy the application code
COPY app.js .

# Make port 8080 available to the world outside this container
EXPOSE 8080

# Define environment variable
ENV PORT=8080
ENV MESSAGE="Hello from EKS! From Senora.dev"

# Run app.js when the container launches
CMD ["node", "app.js"]
