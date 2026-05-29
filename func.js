const fdk = require('@fnproject/fdk');
const { execSync } = require('child_process');

// Parses OCI scheduler bodies that arrive as a Java-style map string,
// for example: {source=.hdfc.source.env,target=.dest.env}.
// Returns an object when parsing succeeds, an empty object for {}, or
// null when the input does not match the expected key=value format.
function parseKeyValueBody(input) {
  // Normalize surrounding whitespace before validating the wrapper braces.
  const trimmed = input.trim();

  // This parser only handles the OCI-style body format wrapped in braces.
  if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
    return null;
  }

  // Remove the outer braces so the remaining content can be split into pairs.
  const content = trimmed.slice(1, -1).trim();

  // Treat an empty body as an empty object rather than a parse failure.
  if (!content) {
    return {};
  }

  const result = {};

  // Split the body into comma-separated key=value segments.
  const parts = content.split(',');

  for (const part of parts) {
    // Each segment must contain an equals sign separating key and value.
    const separatorIndex = part.indexOf('=');
    if (separatorIndex === -1) {
      return null;
    }

    // Extract and trim both sides so inputs like "key = value" still work.
    const key = part.slice(0, separatorIndex).trim();
    const value = part.slice(separatorIndex + 1).trim();

    // Reject malformed pairs such as "=value".
    if (!key) {
      return null;
    }

    // Store the parsed key/value pair on the output object.
    result[key] = value;
  }

  // Return the normalized object for the handler to consume.
  return result;
}

fdk.handle(function(input){
  // Parse the input, which may be a string or an object. If it's a string, attempt to parse it as JSON first
  let parsedInput = input;

  if (typeof input === 'string') {
    try {
      parsedInput = JSON.parse(input);
    } catch (error) {
      parsedInput = parseKeyValueBody(input);
      if (!parsedInput) {
        console.error('ERROR: Failed to parse JSON input body');
        return {'error': 'Invalid JSON input body'};
      }
    }
  }

  // If parsedInput.source is empty, return an error message
  if (!parsedInput || !parsedInput.source) {
    console.error('ERROR: Source is required');
    return {'error': 'Source is required'};
  } 

  // Use input from the parsed body to determine which script to run and capture the output
  let output = '';
  try {
    if (parsedInput.target) {
      // Run the ftp-bridge script and capture the output
      output = execSync(`sh ftp-bridge.sh --source ${parsedInput.source} --target ${parsedInput.target}`).toString();
    } else {
      // Run the connection-test script and capture the output
      output = execSync(`sh connection-test.sh --server ${parsedInput.source}`).toString();
    }
  } catch (error) {
    const stdout = error.stdout ? error.stdout.toString() : '';
    const stderr = error.stderr ? error.stderr.toString() : '';
    const errorOutput = stderr || error.message;

    if (stdout) {
      console.log(stdout);
    }
    console.error(errorOutput);
    return {
      'output': stdout,
      'error': errorOutput,
    };
  }

  // Log the output and return it in JSON format
  console.log(output);
  return {'output': output}
})
