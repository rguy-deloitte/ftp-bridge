const fdk = require('@fnproject/fdk');
const { execSync } = require('child_process');

fdk.handle(function(input){
  let source = '';

  // If input.source is empty, return an error message
  if (!input.source) {
    return {'error': 'Source is required'};
  } else {
    source = input.source;
  }

  if (input.target) {
    // Run the ftp-bridge script and capture the output
    const output = execSync(`sh ftp-bridge.sh --source ${source} --target ${input.target}`).toString();
  } else {
    // Run the connection-test script and capture the output
    const output = execSync(`sh connection-test.sh --server ${source}`).toString();
  }

  // Log the output and return it in JSON format
  console.log(output);
  return {'output': output}
})
