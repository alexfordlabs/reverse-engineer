// widget-api — server entry. Foreign/brownfield fixture for reverse-engineer.
// Wires an Express app to the users route. No project-architect provenance.
const express = require("express");
const usersRouter = require("./routes/users");

const app = express();
app.use(express.json());

app.get("/health", (req, res) => {
  res.json({ status: "ok", version: require("./package.json").version });
});

app.use("/users", usersRouter);

const PORT = process.env.PORT || 3000;
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`widget-api listening on :${PORT}`);
  });
}

module.exports = app;
