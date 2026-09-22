.PHONY: link-agents unlink-agents

AGENT_DIR := $(HOME)/.claude/agents

# Both directories, because a build machine wants the whole team. Only agents/ is
# discovered by a host, so tools/agents/ is how a build role stays out of a client's
# always-on token cost.
AGENT_SRC := agents/*.md tools/agents/*.md

link-agents:
	@mkdir -p $(AGENT_DIR)
	@for f in $(AGENT_SRC); do \
		ln -sf "$(CURDIR)/$$f" "$(AGENT_DIR)/$$(basename $$f)"; \
		echo "linked $$(basename $$f)"; \
	done

unlink-agents:
	@for f in $(AGENT_SRC); do \
		rm -f "$(AGENT_DIR)/$$(basename $$f)"; \
		echo "unlinked $$(basename $$f)"; \
	done
