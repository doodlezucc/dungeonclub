<script lang="ts" module>
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

	export function exitTokenPlacement() {
		unplacedTokenProperties.set(null);
	}
</script>

<script lang="ts">
	import { Board } from '$lib/client/state';
	import { keyStateOf } from 'packages/ui/extensions/ShortcutListener.svelte';
	import { EMPTY_TOKEN_PROPERTIES } from 'shared/token-materializing';
	import { getContext } from 'svelte';
	import type { BoardContext } from '../Board.svelte';
	import TokenBase from './TokenBase.svelte';

	interface Props {
		template: TokenTemplateSnippet | undefined;
		spawnPosition: Position;

		onPlace: (place: TokenPlacementEvent) => void;
	}

	let { template, spawnPosition, onPlace }: Props = $props();

	let position = $state(spawnPosition);

	function onDragToggle(isDragStart: boolean) {
		if (isDragStart) return;

		onPlace({
			position: position,
			templateId: template?.id
		});

		$unplacedTokenProperties = null;
	}

	const activeGridSpace = Board.instance.grid.gridSpace;
	const isGridSnappingDisabled = keyStateOf('DisableGridSnapping');
	const { transformClientToGridSpace, getPanViewEventTarget } = getContext<BoardContext>('board');

	let size = $derived(template?.size ?? 1);

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
	properties={template ?? { ...EMPTY_TOKEN_PROPERTIES }}
	{position}
	style={{
		dragging: true,
		selected: true,
		transparent: true
	}}
	draggableParams={{
		autoDrag: true,
		mouseUpEventListener: getPanViewEventTarget(),
		handleDragging,
		onDragToggle
	}}
/>
