<script lang="ts" context="module">
	export type ModalContext = {
		display: <T, PROPS extends Record<string, any>>(
			component: typeof SvelteComponent<PROPS>,
			props: PROPS
		) => Promise<T>;

		pop: <T>(result?: T) => void;
	};

	interface Modal<T, PROPS extends Record<string, any>> {
		id: number;
		component: typeof SvelteComponent<PROPS>;
		props: PROPS;
		callback: (result: T) => void;
	}
</script>

<script lang="ts">
	import { setContext, SvelteComponent } from 'svelte';
	import { writable } from 'svelte/store';

	const stack = writable<Modal<any, any>[]>([]);

	const nextModalID = writable(0);

	setContext<ModalContext>('modal', {
		display: async (component, props) => {
			return new Promise((resolve) => {
				$stack = [
					...$stack,
					{
						id: $nextModalID++,
						component,
						props,
						callback: resolve
					}
				];
			});
		},

		pop: (result) => {
			const topModal = $stack.at(-1);
			topModal?.callback(result);

			$stack = $stack.slice(0, $stack.length - 1);
		}
	});
</script>

<slot />

<div class="modal-provider" class:show-overlay={$stack.length > 0}>
	{#each $stack as modal (modal.id)}
		<div class="modal" aria-modal="true">
			<svelte:component this={modal.component} {...modal.props} />
		</div>
	{/each}
</div>

<style>
	.modal-provider {
		position: fixed;
		left: 0;
		top: 0;
		width: 100vw;
		height: 100vh;
		z-index: 1;
		pointer-events: none;

		display: flex;
		align-items: center;
		justify-content: center;

		background-color: transparent;
		transition: background-color 0.25s;
	}

	.show-overlay {
		background-color: var(--color-modal-background);
		pointer-events: all;
	}

	.modal {
		position: absolute;
		pointer-events: all;
		display: contents;
	}
</style>
