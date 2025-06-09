<script lang="ts" module>
	import type { TokenPresetSnippet } from '$lib/net';
	import type { Point } from 'packages/math';
	import { writable } from 'svelte/store';

	export interface UnplacedTokenProperties {
		tokenPreset?: TokenPresetSnippet;
		triggeringEvent: MouseEvent;
	}

	export interface TokenPlacementEvent {
		position: Point;
		presetId?: string;
	}

	export const unplacedTokenProperties = writable<UnplacedTokenProperties | null>(null);

	export function exitTokenPlacement() {
		unplacedTokenProperties.set(null);
	}
</script>

<script lang="ts">
	import { Board } from '$lib/client/state';
	import { EMPTY_TOKEN_PROPERTIES } from '$lib/net/token-materializing';
	import { keyStateOf } from '$lib/ui/util/ShortcutListener.svelte';
	import { getContext } from 'svelte';
	import type { BoardContext } from '../Board.svelte';
	import TokenBase from './TokenBase.svelte';

	interface Props {
		preset: TokenPresetSnippet | undefined;
		spawnPosition: Point;

		onPlace: (place: TokenPlacementEvent) => void;
	}

	let { preset, spawnPosition, onPlace }: Props = $props();

	let position = $state(spawnPosition);

	function onDragToggle(isDragStart: boolean) {
		if (isDragStart) return;

		onPlace({
			position: position,
			presetId: preset?.id
		});

		$unplacedTokenProperties = null;
	}

	const activeGridSpace = Board.instance.grid.gridSpace;
	const isGridSnappingDisabled = keyStateOf('DisableGridSnapping');
	const { transformClientToGridSpace, getPanViewEventTarget } = getContext<BoardContext>('board');

	let size = $derived(preset?.size ?? 1);

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
	properties={preset ?? { ...EMPTY_TOKEN_PROPERTIES }}
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
