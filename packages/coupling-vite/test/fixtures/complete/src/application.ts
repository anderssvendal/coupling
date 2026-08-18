import "./application.css";
import logoUrl from "./images/logo.svg";
import outsideUrl from "../vendor/outside.svg";
import { sharedMessage } from "./shared.js";

const image = document.createElement("img");
image.src = logoUrl;
image.dataset.outside = outsideUrl;
document.body.append(image);

console.log(sharedMessage);
void import("./lazy.js");
