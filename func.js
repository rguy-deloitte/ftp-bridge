const fdk = require('@fnproject/fdk');
const { execSync } = require('child_process');

fdk.handle(function(input){
  let source = 'lockton.source.env';
  let target = 'lockton.target.env';
  if (input.source) {
    source = input.source;
  }
  if (input.target) {
    target = input.target;
  }

  // Run the shell script and capture the output
  const output = execSync(`sh ftp-bridge.sh --source ${source} --target ${target}`).toString();
  // const output = execSync(`sh connection-test.sh --server ${credentials}`).toString();

  console.log(`ftp-bridge running:\n${output}`);
  // console.log(`\nConnection test has been run, output:\n${output}`);
  return {'output': output}
})
