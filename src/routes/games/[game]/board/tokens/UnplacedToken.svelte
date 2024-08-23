<script lang="ts" context="module">
	import type { Position } from '$lib/compounds';
	import type { TokenTemplateSnippet } from 'shared';
	import { writable } from 'svelte/store';

	export interface UnplacedTokenProperties {
		tokenTemplate?: TokenTemplateSnippet;
		triggeringEvent: MouseEvent;
	}

	export interface TokenPlacementEvent {
		position: Position;
		templateId?: string;
	}

	export const unplacedTokenProperties = writable<UnplacedTokenProperties | null>(null);
</script>

<script lang="ts">
	import { Board } from 'client/state';
	import { KeyState, keyStateOf } from 'components/extensions/ShortcutListener.svelte';
	import { createEventDispatcher, getContext } from 'svelte';
	import type { BoardContext } from '../Board.svelte';
	import TokenBase from './TokenBase.svelte';

	export let template: TokenTemplateSnippet | undefined;
	export let spawnPosition: Position;

	$: position = spawnPosition;

	const dispatch = createEventDispatcher<{
		place: TokenPlacementEvent;
	}>();

	function onDragToggle(isDragStart: boolean) {
		if (isDragStart) return;

		$unplacedTokenProperties = null;

		dispatch('place', {
			position: position,
			templateId: template?.id
		});
	}

	const activeGridSpace = Board.instance.grid.gridSpace;
	const isGridSnappingDisabled = keyStateOf(KeyState.DisableGridSnapping);
	const { transformClientToGridSpace } = getContext<BoardContext>('board');

	$: size = template?.size ?? 1;

	function handleDragging(ev: MouseEvent) {
		const mouseInGridSpace = transformClientToGridSpace({ x: ev.clientX, y: ev.clientY });

		if ($isGridSnappingDisabled) {
			position = {
				x: mouseInGridSpace.x,
				y: mouseInGridSpace.y * $activeGridSpace!.tileHeightRatio
			};
		} else {
			const snapped = $activeGridSpace!.snapShapeToGrid({
				center: mouseInGridSpace,
				size: size
			});

			position = snapped;
		}
	}
</script>

<TokenBase
	{template}
	{size}
	{position}
	style={{
		dragging: true,
		selected: true,
		transparent: true
	}}
	draggableParams={{
		autoDrag: true,
		handleDragging,
		onDragToggle
	}}
/>
