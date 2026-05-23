const contactForm = document.querySelector("#contactForm");
const formNote = document.querySelector("#formNote");

if (contactForm && formNote) {
  contactForm.addEventListener("submit", (event) => {
    event.preventDefault();
    const name = document.querySelector("#name").value.trim();
    formNote.textContent = `Thank you, ${name}. Your message is ready for submission.`;
    contactForm.reset();
  });
}
