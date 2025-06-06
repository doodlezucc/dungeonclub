<script lang="ts">
	import { Button } from 'packages/ui';
	import { Column } from 'packages/ui/layout';
	import type { ModalContext } from 'packages/ui/modal';
	import { getContext } from 'svelte';
	import SelectBoardDialog from '../board-selection/SelectBoardDialog.svelte';

	const modal = getContext<ModalContext>('modal');

	async function switchBoard() {
		await modal.display(SelectBoardDialog, {});
	}
</script>

<Column gap="normal">
	<Button raised onclick={switchBoard}>Switch Board</Button>
	<Button raised>Edit Board</Button>
	<Button raised>Roll Dice</Button>
</Column>
