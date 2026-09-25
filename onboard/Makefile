.PHONY: link-agents unlink-agents

AGENT_DIR := $(HOME)/.claude/agents

link-agents:
	@mkdir -p $(AGENT_DIR)
	@for f in agents/*.md; do \
		ln -sf "$(CURDIR)/$$f" "$(AGENT_DIR)/$$(basename $$f)"; \
		echo "linked $$(basename $$f)"; \
	done

unlink-agents:
	@for f in agents/*.md; do \
		rm -f "$(AGENT_DIR)/$$(basename $$f)"; \
		echo "unlinked $$(basename $$f)"; \
	done
