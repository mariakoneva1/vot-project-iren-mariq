from __future__ import annotations

from html import escape


def _render_task_card(task: dict[str, str | int]) -> str:
    task_id = int(task["id"])
    next_label = "Move Forward" if task["status"] != "DONE" else "Done"
    button = (
        f"""
        <form action="/tasks/{task_id}/advance" method="post">
          <button type="submit" {"disabled" if task["status"] == "DONE" else ""}>{next_label}</button>
        </form>
        """
    )
    return f"""
    <article class="task-card status-{escape(str(task["status"]).lower())}">
      <div class="task-header">
        <h3>{escape(str(task["title"]))}</h3>
        <span>{escape(str(task["status"]))}</span>
      </div>
      <p>{escape(str(task["description"])) or "No description provided."}</p>
      {button}
    </article>
    """


def render_dashboard(app_name: str, tasks: list[dict[str, str | int]]) -> bytes:
    statuses = ("TODO", "DOING", "DONE")
    columns = []
    for status in statuses:
        cards = "".join(_render_task_card(task) for task in tasks if task["status"] == status)
        columns.append(
            f"""
            <section class="board-column">
              <header>
                <h2>{status}</h2>
                <span>{sum(1 for task in tasks if task["status"] == status)} tasks</span>
              </header>
              <div class="column-body">
                {cards or '<p class="empty-state">No tasks in this stage yet.</p>'}
              </div>
            </section>
            """
        )

    html = f"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>{escape(app_name)}</title>
        <link rel="stylesheet" href="/static/styles.css">
      </head>
      <body>
        <main class="layout">
          <section class="hero">
            <div>
              <p class="eyebrow">DevOps Demo App</p>
              <h1>{escape(app_name)}</h1>
              <p class="hero-copy">
                A small planning board that is easy to containerize, test, observe and deploy with GitOps.
              </p>
            </div>
            <form class="task-form" action="/tasks" method="post">
              <label>
                Title
                <input type="text" name="title" maxlength="80" required>
              </label>
              <label>
                Description
                <textarea name="description" rows="4" maxlength="240"></textarea>
              </label>
              <button type="submit">Create Task</button>
            </form>
          </section>
          <section class="board">
            {''.join(columns)}
          </section>
        </main>
      </body>
    </html>
    """
    return html.encode("utf-8")

