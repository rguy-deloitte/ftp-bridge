const fdk = require('@fnproject/fdk');
const { execSync } = require('child_process');

fdk.handle(function(input){
  // If input.source is empty, return an error message
  if (!input.source) {
    return {'error': 'Source is required'};
  } 

  let output = '';
  if (input.target) {
    // Run the ftp-bridge script and capture the output
    output = execSync(`sh ftp-bridge.sh --source ${input.source} --target ${input.target}`).toString();
  } else {
    // Run the connection-test script and capture the output
    output = execSync(`sh connection-test.sh --server ${input.source}`).toString();
  }

  // Log the output and return it in JSON format
  console.log(output);
  return {'output': output}
})
