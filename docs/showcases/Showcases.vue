<script setup lang="ts">
import showcases from "./showcases"
import Showcase from "./Showcase.vue"
</script>

<template>
    <div class="Showcases">
        <template v-for="(showcase, index) in showcases" :key="index">
            <div v-if="Array.isArray(showcase)" class="row">
                <div
                    v-for="(elem, elemIndex) in showcase"
                    :key="elemIndex"
                    class="item"
                    :class="`grid-${showcase.length}`"
                >
                    <Showcase v-bind="elem" />
                </div>
            </div>
            <Showcase v-else v-bind="showcase" />
        </template>
    </div>
</template>

<style scoped>
.Showcases {
    margin-top: 24px;
    display: flex;
    flex-direction: column;
    gap: 24px;
}

.row {
    display: flex;
    gap: 24px;
}

/* TODO: responsiveness on mobile */
.item.grid-2 {
    width: calc(100% / 2);
}

.item.grid-3 {
    width: calc(100% / 3);
}

.item.grid-4 {
    width: calc(100% / 4);
}
</style>
