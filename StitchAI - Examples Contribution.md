# StitchAI - Examples Contribution	

We’re working on an AI feature for Stitch. It’s a Copilot-like feature that generates simple graphs based on a user prompt.

The model is an OpenAI 4o model fine-tuned on prompt <> action pairs. We need more trining data though! And that’s where you come in - we’d love your help in creating training examples for our model. 

The way to do this is to open the app and create a new project. Click the AI Recorder button:
![](StitchAI_Examples_Contribution/AIRecorder.png)
and then start creating your example just like you would with making any other graph. 

For now, focus on creating simple examples; not full, complete prototypes. Somewhere on the order of 5 - 10 total nodes for the graph

When you’re done creating the graph, enter the prompt 
![](StitchAI_Examples_Contribution/PromptView.png)

### Descriptive Prompts
Make sure your prompts are descriptive, and fully articulate everything that is happening in the graph. 

For example, a graph like this would be “find the square root of 2 times pi”
![](StitchAI_Examples_Contribution/MathExample.png)

For this, it would be “make an orange rounded rect with a radius of 20 that I can drag around”
![](StitchAI_Examples_Contribution/DraggableRectExample.png)



### Review and Submission

Once you’re done that, you can review the graph again to make sure it’s correct:
![](StitchAI_Examples_Contribution/SubmissionView.png)

Once you’re satisifed with your example, hit Submit. 

The JSON that makes up the graph and the prompt you entered gets uploaded to our Supabase table. Once we have a certain number of new examples, we’ll train a new fine-tuned model on that data; and then release a new TestFlight with it. 

This is incredibly helpful work for helping us to further imporve our fine-tuned model.
