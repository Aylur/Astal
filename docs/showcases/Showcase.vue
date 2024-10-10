<script setup>
defineProps({
    src: { type: String, required: true },
    label: { type: String, required: true },
    url: { type: String, required: true },
    icon: { type: String, required: false, default: "" },
})
</script>

<template>
    <figure class="showcase">
        <div>
            <a :href="url" target="_blank">
                <img :src="src" :alt="label">
            </a>
            <i :class="icon" class="language-icon" />
        </div>
        <figcaption>
            <a
                :href="url"
                class="label-link"
                target="_blank"
            >
                {{ label }}
            </a>
        </figcaption>
    </figure>
</template>

<style scoped>
.showcase {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 1rem;
    border-radius: 15px;
    background-color: var(--vp-c-bg-soft);
    transition:
        transform 0.3s ease,
        box-shadow 0.3s ease;
}

.showcase:hover {
    transform: translateY(-5px);
    box-shadow: 0 10px 20px rgba(0, 0, 0, 0.1);
}

.showcase:hover img {
    transform: scale(1.05);
}

.showcase div {
    position: relative;
    display: inline-block;
    width: 100%;
    border-radius: 5px;
    overflow: hidden;
}

.showcase img {
    width: 100%;
    border-radius: 5px;
    transition: transform 0.3s ease;
}

.showcase i {
    position: absolute;
    bottom: 5px;
    right: 5px;
    padding: 0.5rem;
    background: var(--vp-c-bg-soft);
    border-radius: 100%;
    font-size: 1rem;
}

figcaption {
    margin-top: 0.8rem;
    text-align: center;
}

.label-link {
    text-decoration: none;
    color: var(--vp-c-text-primary);
    font-weight: semibold;
    font-size: 1rem;
    transition: color 0.3s ease;
}

.label-link:hover {
    color: var(--vp-c-brand);
}
</style>
