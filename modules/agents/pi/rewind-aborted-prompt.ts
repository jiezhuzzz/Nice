import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const command = "rewind-aborted-prompt";

export default function (pi: ExtensionAPI) {
  pi.on("agent_settled", async (event, ctx) => {
    if (!event.aborted || ctx.mode !== "tui") return;
    const branch = ctx.sessionManager.getBranch();
    const promptIndex = branch.findLastIndex((entry) => entry.type === "message" && entry.message.role === "user");
    if (promptIndex < 0) return;
    // A run that reached a tool call may have changed the workspace, so the
    // model must keep seeing it.
    const rewindable = branch
      .slice(promptIndex + 1)
      .every((entry) =>
        entry.type === "message"
          ? entry.message.role === "assistant" &&
            ["aborted", "error"].includes(entry.message.stopReason) &&
            !entry.message.content.some((part) => part.type === "toolCall")
          : entry.type !== "compaction",
      );
    if (rewindable) pi.sendUserMessage(`/${command} ${branch[promptIndex].id}`, { expandPromptTemplates: true });
  });

  pi.registerCommand(command, {
    description: "Rewind an aborted prompt into the editor",
    handler: async (entryId, ctx) => {
      const entry = ctx.sessionManager.getEntry(entryId.trim());
      if (entry?.type !== "message" || entry.message.role !== "user") return;
      const { content } = entry.message;
      const prompt =
        typeof content === "string"
          ? content
          : content.flatMap((part) => (part.type === "text" ? [part.text] : [])).join("\n");
      // navigateTree fills the editor only when it is empty, which it is not
      // once Pi has restored queued messages there.
      const queued = ctx.ui.getEditorText().trim();
      const { cancelled } = await ctx.navigateTree(entry.id);
      if (!cancelled && queued) ctx.ui.setEditorText(`${prompt}\n\n${queued}`);
    },
  });
}
