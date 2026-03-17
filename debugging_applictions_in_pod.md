# Debugging Applications in Pods

That's great context! Since you want to set breakpoints in your code, we'll focus on Remote Debugging for your .NET backend.

For the Angular frontend, debugging typically happens locally in your browser's Developer Tools by inspecting the running JS/TS code and making calls to the remote API.

Let's focus on the .NET pod first, as that is the application running remotely.

To set true code breakpoints, your .NET application needs a special component to allow your IDE (like VS Code or Visual Studio) to connect and take control of the running process.

This process usually involves three main steps:

1. **Image Prep**: Ensure the container image includes the necessary debugger tool.
2. **Pod Prep**: Configure the Kubernetes pod to expose the debugger port.
3. **Local Connect**: Use kubectl port-forward and configure your IDE.

## Step 1: Preparing the Container Image

For remote debugging a .NET application on Linux (which is common for containers), we need to ensure the VSDBG (Visual Studio Debugger) tool is present in your container image.

Before we worry about the Kubernetes networking, what configuration or files do you need to add to your .NET Dockerfile or application settings to tell the running app process to:

- Start in a debug-ready mode?
- Listen on a specific port for an external debugger to connect?
- If you're using VS Code, how does the launch.json file usually communicate with the remote process? What command or environment variables often trigger .NET Core's remote debugging functionality?