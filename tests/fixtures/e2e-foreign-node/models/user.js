// user model — the data shape + validation rules for widget-api.
// "Find the data first": this is the schema the reverse-engineer pass anchors on.
const crypto = require("crypto");

// The User entity. Fields: id (uuid), email (unique), displayName, role, createdAt.
class User {
  constructor({ email, displayName, role }) {
    this.id = crypto.randomUUID();
    this.email = email;
    this.displayName = displayName;
    this.role = role || "member";
    this.createdAt = new Date().toISOString();
  }

  // Public projection — never leak internal fields beyond this shape.
  toPublicJSON() {
    return {
      id: this.id,
      email: this.email,
      displayName: this.displayName,
      role: this.role,
      createdAt: this.createdAt,
    };
  }
}

// Business rules: email required + well-formed; role must be a known value.
const ROLES = ["member", "admin"];

function validateUser(body) {
  const errors = [];
  if (!body || typeof body.email !== "string" || !body.email.includes("@")) {
    errors.push("email is required and must be a valid address");
  }
  if (body && body.role && !ROLES.includes(body.role)) {
    errors.push(`role must be one of: ${ROLES.join(", ")}`);
  }
  return errors;
}

module.exports = { User, validateUser, ROLES };
