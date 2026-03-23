const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const commitMessages = [
  'docs: update documentation',
  'chore: code cleanup',
  'refactor: improve code structure',
  'style: format code',
  'fix: minor bug fix',
  'feat: enhance functionality',
  'perf: optimize performance',
  'test: add test coverage',
  'build: update build config',
  'ci: improve CI pipeline',
  'docs: add inline comments',
  'chore: update dependencies',
  'refactor: simplify logic',
  'style: improve readability',
  'fix: handle edge case',
  'feat: add helper function',
  'perf: reduce complexity',
  'docs: clarify usage',
  'chore: cleanup unused code',
  'refactor: extract method',
];

const logFile = 'CHANGELOG.md';

function getRandomMessage() {
  return commitMessages[Math.floor(Math.random() * commitMessages.length)];
}

function makeCommit(i) {
  const timestamp = new Date().toISOString();
  const entry = `\n## Update ${i} - ${timestamp}\n- Iteration ${i} improvement\n`;
  
  fs.appendFileSync(logFile, entry);
  
  try {
    execSync('git add .', { stdio: 'pipe' });
    execSync(`git commit -m "${getRandomMessage()} #${i}"`, { stdio: 'pipe' });
    return true;
  } catch (e) {
    return false;
  }
}

async function main() {
  const targetCommits = 1000;
  let successCount = 0;
  
  // Initialize changelog if it doesn't exist
  if (!fs.existsSync(logFile)) {
    fs.writeFileSync(logFile, '# Changelog\n\nAll notable changes to this project.\n');
    execSync('git add .', { stdio: 'pipe' });
    execSync('git commit -m "docs: initialize changelog"', { stdio: 'pipe' });
    successCount++;
  }
  
  console.log(`Starting ${targetCommits} commits...`);
  
  for (let i = 1; i <= targetCommits; i++) {
    if (makeCommit(i)) {
      successCount++;
    }
    
    if (i % 50 === 0) {
      console.log(`Progress: ${i}/${targetCommits} commits (${successCount} successful)`);
    }
  }
  
  console.log(`\nDone! Created ${successCount} commits.`);
  console.log('Now pushing to remote...');
  
  try {
    execSync('git push origin master', { stdio: 'inherit' });
    console.log('Push complete!');
  } catch (e) {
    console.log('Push failed, try manually: git push origin master');
  }
}

main();
