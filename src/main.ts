import './style.css'

const worker = new Worker(new URL('./worker.ts', import.meta.url))
worker.onmessage = (event) => {
  console.log(event.data)
}