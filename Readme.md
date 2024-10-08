[![Bounties on BountyHub](https://img.shields.io/badge/Bounties-on%20BountyHub-yellow)](https://bountyhub.dev?repo=omarsoufiane/github-gateway)

# GitHub API Backend

This project is a backend micro-service that makes calls to GitHub organizations and get their last repositories with issues and pull requests 

## Getting Started

### Prerequisites

- Node.js or Docker installed
- GitHub Developer Account for obtaining an access token

### Installation

1. Clone the repository:
    git clone https://github.com/omarsoufiane/github-gateway.git

2. Navigate to the repository:
    cd github-gateway

3. Install dependencies:
    npm install

### Configuration

Create a .env file in the root of the project and put the token you obtained from GitHub:

GITHUB_ACCESS_TOKEN=your_actual_access_token
PORT=3000


### Usage 

1. Using npm:
    npm run build
    npm run start

2. Using Docker:
    docker build -t your-image-name .
    docker run -p 3000:3000 your-image-name


The server will be running at http://localhost:3000 by default.

Make get request to 'http://localhost:3000/orgs/{organisation-name}/' to get organisation informations
