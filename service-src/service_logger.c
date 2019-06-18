#include "skynet.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

struct logger {
	FILE * handle;
	int close;
};

struct logger *
jmlogger_create(void) {
	struct logger * inst = skynet_malloc(sizeof(*inst));
	inst->handle = NULL;
	inst->close = 0;
	return inst;
}

void
jmlogger_release(struct logger * inst) {
	if (inst->close) {
		fclose(inst->handle);
	}
	skynet_free(inst);
}

static int
_logger(struct skynet_context * context, void *ud, int type, int session, uint32_t source, const void * msg, size_t sz) {
	struct logger * inst = ud;
	if (type == 0) {
		fprintf(inst->handle, "[:%08x] ",source);		
	}
	fwrite(msg, sz , 1, inst->handle);
	if (type == 0) {
		fprintf(inst->handle, "\n");		
	}
	fflush(inst->handle);

	return 0;
}

int
jmlogger_init(struct logger * inst, struct skynet_context *ctx, const char * parm) {
	if (parm) {
		inst->handle = fopen(parm,"a+");
		if (inst->handle == NULL) {
			return 1;
		}
		inst->close = 1;
	} else {
		inst->handle = stdout;
	}
	if (inst->handle) {
		skynet_callback(ctx, inst, _logger);
		//skynet_command(ctx, "REG", ".logger");
		return 0;
	}
	return 1;
}
