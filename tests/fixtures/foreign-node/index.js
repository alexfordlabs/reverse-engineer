// A tiny foreign Node entrypoint — fixture for reverse-engineer P0 detection.
function greet(name) {
  return `hello, ${name}`;
}

console.log(greet("world"));

module.exports = { greet };
